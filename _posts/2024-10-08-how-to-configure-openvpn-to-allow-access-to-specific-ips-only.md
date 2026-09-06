---
layout: post
title: "OpenVPN: Restrict Client Access to Specific IPs Only"
description: "How to restrict OpenVPN clients to a limited set of destination IPs, using client-config-dir routes, a client-connect script, and iptables rules."
date: 2024-10-08 00:00 +0000
categories: [Security]
tags: [openvpn, networking, firewall, security]
---
<audio controls preload="metadata" src="/assets/audio/how-to-configure-openvpn-to-allow-access-to-specific-ips-only-summary.ogg">
  Your browser does not support the audio element.
</audio>


OpenVPN's default behavior is full network access: once a client connects, it can reach anything routable through the tunnel. That's not what you want for a contractor VPN, a support tunnel, or any profile that only needs a handful of internal services. Restricting a client to specific IPs takes three pieces working together: a `client-config-dir` route, a script that runs on connect, and iptables rules that actually enforce it.

## Prerequisites

- A working OpenVPN server
- Root or sudo access to the server
- Basic knowledge of networking and firewall concepts

## Server configuration

Edit `/etc/openvpn/server.conf`:

```
# DNS setup
push "dhcp-option DNS 10.8.0.1"
push "redirect-gateway def1 bypass-dhcp"

# This helps prevent DNS leaks on Windows
push "block-outside-dns"

# Client configuration directory
client-config-dir /etc/openvpn/ccd
route 10.8.0.0 255.255.255.0

# Logging
log-append /var/log/openvpn.log
status /var/log/openvpn-status.log

# Enable running external scripts
script-security 2
client-connect /etc/openvpn/client-connect.sh
```

Create the client config directory:

```bash
sudo mkdir -p /etc/openvpn/ccd
sudo chown nobody:nogroup /etc/openvpn/ccd
sudo chmod 755 /etc/openvpn/ccd
```

Push the specific routes clients are allowed to use:

```
push "route 192.168.1.0 255.255.255.0"
push "route 10.0.0.5 255.255.255.255"
```

## Enforcing the restriction with a client-connect script

Pushed routes tell the client which networks to send through the tunnel; they don't stop the server from forwarding traffic anywhere else. The actual enforcement happens in iptables, applied by a script that runs every time a client connects.

List of allowed destination IPs:

```bash
echo "192.168.1.100
10.0.0.50
203.0.113.10" > /etc/openvpn/allowed_ips.txt
```

`/etc/openvpn/client-connect.sh`:

```bash
#!/bin/bash

# Read the allowed IPs
ALLOWED_IPS=$(cat /etc/openvpn/allowed_ips.txt)

# Create iptables rules for each allowed IP
for IP in $ALLOWED_IPS; do
    iptables -A FORWARD -i tun+ -d $IP -j ACCEPT
done

# Drop all other forward traffic from tun interfaces
iptables -A FORWARD -i tun+ -j DROP
```

```bash
chmod +x /etc/openvpn/client-connect.sh
```

## Managing rules directly with iptables

If you'd rather manage rules by hand instead of through the connect script:

```bash
# Allow all traffic for other VPN clients
sudo iptables -A FORWARD -i tun0 -o eth0 -s 10.8.0.0/24 -j ACCEPT

# Rules for a specific client (10.8.0.5)
sudo iptables -A FORWARD -i tun0 -o eth0 -s 10.8.0.5 -d 93.184.216.34 -j ACCEPT
sudo iptables -A FORWARD -i tun0 -o eth0 -s 10.8.0.5 -p udp --dport 53 -j ACCEPT
sudo iptables -A FORWARD -i tun0 -o eth0 -s 10.8.0.5 -j DROP
```

```bash
# View current rules
sudo iptables -L -v -n

# Delete a specific rule
sudo iptables -L --line-numbers
sudo iptables -D CHAIN_NAME RULE_NUMBER
```

Back up and restore:

```bash
sudo iptables-save > /tmp/iptables.rules
sudo iptables-restore < /tmp/iptables.rules
```

A backup script, if you want this on a cron job:

```bash
#!/bin/bash
BACKUP_DIR="/path/to/backup/directory"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/iptables_backup_$TIMESTAMP.rules"
iptables-save > "$BACKUP_FILE"
echo "Backup saved to $BACKUP_FILE"
```

## Per-client configuration

To give one client its own IP and routes, create a file in `ccd` named after the client:

```bash
sudo nano /etc/openvpn/ccd/client1
```

```
# Assign a specific IP to the client
ifconfig-push 10.8.0.200 255.255.255.255

# Push specific routes to this client
push "route 192.168.1.0 255.255.255.0"
```

```bash
sudo chown nobody:nogroup /etc/openvpn/ccd/client1
sudo chmod 644 /etc/openvpn/ccd/client1
```

## Verifying it worked

```bash
sudo systemctl status openvpn
# or
sudo service openvpn status
```

```bash
# Check routing table
netstat -r
ip route

# Check tun interface
ifconfig tun0
ip addr show tun0

# Check OpenVPN connections
ss -anp | grep openvpn
netstat -anp | grep openvpn
```

```bash
tail -f /var/log/openvpn.log
```

## What this buys you, and what it doesn't

Pushed routes and iptables rules restrict where traffic can go, but they're enforced on the server, not the client: a compromised or misconfigured client is still authenticated, just unable to reach much. That's the right trade-off for a contractor or support tunnel. It isn't a substitute for per-client certificates and proper key management, which this setup assumes you've already solved.
