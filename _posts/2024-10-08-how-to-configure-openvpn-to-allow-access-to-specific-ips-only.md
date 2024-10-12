---
layout: post
title: How to Configure OpenVPN to Allow Access to Specific IPs Only
date: 2024-10-08 00:00 +0000
categories: OpenVPN
tags: [openvpn, devops, firewall]
---
# How to Configure OpenVPN to Allow Access to Specific IPs Only

## Introduction
OpenVPN is a popular open-source VPN solution that provides secure point-to-point or site-to-site connections. While it's often used to provide full network access, there are scenarios where you might want to restrict VPN users to accessing only specific IP addresses. This article will guide you through the process of configuring OpenVPN to allow connections to a limited set of IP addresses and provide additional advanced configurations.

## Prerequisites
- A working OpenVPN server
- Root or sudo access to the server
- Basic knowledge of networking and firewall concepts

## OpenVPN Server Setup

### 1. Basic Configuration

Edit your OpenVPN server configuration file (usually located at `/etc/openvpn/server.conf`) and add the following lines:

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

### 2. Create Client Configuration Directory

```bash
sudo mkdir -p /etc/openvpn/ccd
sudo chown nobody:nogroup /etc/openvpn/ccd
sudo chmod 755 /etc/openvpn/ccd
```

### 3. Limit Routes for Clients

To restrict clients to specific routes, add these lines to your server config:

```
push "route 192.168.1.0 255.255.255.0"
push "route 10.0.0.5 255.255.255.255"
```

### 4. Create a list of allowed IP addresses

Create a file that contains the list of IP addresses you want to allow:

```bash
echo "192.168.1.100
10.0.0.50
203.0.113.10" > /etc/openvpn/allowed_ips.txt
```

### 5. Create the client-connect script

Create a new file `/etc/openvpn/client-connect.sh` with the following content:

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

Make the script executable:

```bash
chmod +x /etc/openvpn/client-connect.sh
```

## Firewall Configuration with iptables

### 1. Basic iptables Rules

```bash
# Allow all traffic for other VPN clients
sudo iptables -A FORWARD -i tun0 -o eth0 -s 10.8.0.0/24 -j ACCEPT

# Rules for a specific client (10.8.0.5)
sudo iptables -A FORWARD -i tun0 -o eth0 -s 10.8.0.5 -d 93.184.216.34 -j ACCEPT
sudo iptables -A FORWARD -i tun0 -o eth0 -s 10.8.0.5 -p udp --dport 53 -j ACCEPT
sudo iptables -A FORWARD -i tun0 -o eth0 -s 10.8.0.5 -j DROP
```

### 2. Managing iptables Rules

To view current rules:
```bash
sudo iptables -L -v -n
```

To delete a specific rule:
```bash
sudo iptables -L --line-numbers
sudo iptables -D CHAIN_NAME RULE_NUMBER
```

### 3. Backup and Restore iptables Rules

To backup:
```bash
sudo iptables-save > /tmp/iptables.rules
```

To restore:
```bash
sudo iptables-restore < /tmp/iptables.rules
```

### 4. Automated Backup Script

Create a script to automatically backup iptables rules:

```bash
#!/bin/bash
BACKUP_DIR="/path/to/backup/directory"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/iptables_backup_$TIMESTAMP.rules"
iptables-save > "$BACKUP_FILE"
echo "Backup saved to $BACKUP_FILE"
```

## Client-Specific Configurations

To apply specific configurations to individual clients:

1. Create a file in the `ccd` directory with the client's name:
   ```bash
   sudo nano /etc/openvpn/ccd/client1
   ```

2. Add client-specific configurations, such as:
   ```
   # Assign a specific IP to the client
   ifconfig-push 10.8.0.200 255.255.255.255

   # Push specific routes to this client
   push "route 192.168.1.0 255.255.255.0"
   ```

3. Set proper permissions:
   ```bash
   sudo chown nobody:nogroup /etc/openvpn/ccd/client1
   sudo chmod 644 /etc/openvpn/ccd/client1
   ```

## Troubleshooting and Verification

### 1. Check OpenVPN Status
```bash
sudo systemctl status openvpn
# or
sudo service openvpn status
```

### 2. Verify Network Configuration
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

### 3. Check Logs
Monitor OpenVPN logs for any issues:
```bash
tail -f /var/log/openvpn.log
```

## Conclusion

By following this comprehensive guide, you've not only configured OpenVPN to restrict access to specific IP addresses but also learned about advanced configurations, client-specific settings, and proper firewall management. This setup provides a robust and flexible VPN solution that can be tailored to meet specific security requirements.

Remember to regularly update your configurations, manage your firewall rules carefully, and monitor your VPN server for any unusual activity. With proper management, this setup will provide a secure and controlled access point to your network resources.
