---
title: "Browsing Through a Remote SSH Server Without DNS Leaks"
date: 2025-12-03
tags:
    - security
    - ssh
    - dns
    - socks5
    - privacy
    - tutorial
---
# Browsing Through a Remote SSH Server Without DNS Leaks (Security Education)

## Why DNS leaks matter

Even when your web traffic is encrypted (HTTPS), **DNS requests** can reveal which domains you’re visiting. On managed networks (office Wi-Fi, corporate VPN, hotels), DNS is often monitored, filtered, or logged. That can create privacy and security issues such as:

* **Visibility**: networks can see the domains you request
* **Censorship / filtering**: DNS can be blocked or rewritten
* **Tracking**: DNS logs can be correlated to users/devices
* **Targeting**: knowing what you visit can enable phishing/social engineering

If you’re on a **managed work Mac**, you may find that **DNS over HTTPS (DoH)** is disabled by company policy. In that environment, a practical, standard engineering approach is to move DNS resolution off-device by routing browsing through a remote machine over SSH.

This article shows how to do that safely using an **SSH SOCKS proxy**, and how to verify you aren’t leaking DNS.

> This is not “hacking.” It’s a common technique used by developers, SREs, and security engineers for secure remote access and testing. Always follow your organization’s policies.

---

## Threat model (what this protects against)

This setup protects you from:

* Local network observers seeing your DNS queries
* Corporate DNS logging on the client machine
* DNS-based censorship on the local network

It does **not** protect you from:

* The remote server’s ISP seeing your traffic (they may see DNS and IPs, depending on your server DNS configuration)
* Websites tracking you via cookies/fingerprinting
* Malware or a compromised remote server

---

## Overview of the solution

You will:

1. Create an encrypted SSH tunnel from your laptop to your Ubuntu server.
2. Use that tunnel as a local **SOCKS5 proxy** (e.g., `127.0.0.1:1080`).
3. Configure your browser to send **all traffic + DNS** through the SOCKS proxy.
4. Verify that your **public IP and DNS servers** match the remote server (not your local network).

---

## Prerequisites

* A remote Ubuntu server you can SSH into
* SSH access (username + IP or hostname)
* A browser that supports SOCKS + remote DNS (Firefox recommended)

Optional but recommended:

* SSH keys (instead of password)
* A non-root user on the server

---

## Step 1 — Create the SSH SOCKS tunnel

Open Terminal on your Mac and run:

```bash
ssh -D 1080 -N username@your_server_ip
```

What the flags mean:

* `-D 1080` : dynamic port forward → creates a SOCKS5 proxy on localhost port 1080
* `-N` : don’t run a remote command (tunnel only)

Keep this terminal window open while browsing.

### Make it more stable (recommended)

Add keep-alives so the tunnel doesn’t silently die on flaky networks:

```bash
ssh -D 1080 -N \
  -o ServerAliveInterval=60 \
  -o ServerAliveCountMax=3 \
  username@your_server_ip
```

---

## Step 2 — Configure Firefox to proxy traffic *and DNS*

Firefox is the easiest way to avoid DNS leaks with SOCKS.

1. Open Firefox → **Settings**
2. Search for **Network Settings**
3. Click **Settings…**
4. Choose **Manual proxy configuration**
5. Set:

   * **SOCKS Host**: `127.0.0.1`
   * **Port**: `1080`
   * Select **SOCKS v5**
6. Enable:

   * ✅ **Proxy DNS when using SOCKS v5**

That checkbox is critical. Without it, Firefox might still do DNS locally.

---

## Step 3 — Verify: public IP + DNS should be remote

With the SSH tunnel running and Firefox proxy enabled:

* Visit `https://ipleak.net` or `https://dnsleaktest.com`
* Confirm:

  * **Your public IP** is the Ubuntu server’s IP (or its ISP/hosting provider)
  * **DNS servers** are associated with the server (not your local ISP/corporate DNS)

If you still see corporate DNS servers, double-check:

* Firefox is using SOCKS v5
* “Proxy DNS when using SOCKS v5” is enabled
* You didn’t configure only HTTP proxy (SOCKS is the key here)

---

## Step 4 — Common pitfalls (and how to avoid them)

### Pitfall A: WebRTC leaks

WebRTC can reveal network information in some setups.

Mitigation (Firefox):

1. Type `about:config` in the address bar
2. Search `media.peerconnection.enabled`
3. Set it to `false`

### Pitfall B: Mixing proxied + non-proxied browsing

Use a dedicated profile for proxied browsing (privacy hygiene).

Create a new Firefox profile:

```bash
/Applications/Firefox.app/Contents/MacOS/firefox -P
```

Then configure the proxy only in that profile.

### Pitfall C: Tunnel drops mid-session

If SSH drops, your browser might fail open (or just stop loading). Keep-alives help; you can also run a second terminal to monitor:

```bash
lsof -i :1080
```

---

## Step 5 — Optional: Put the SSH config in `~/.ssh/config`

This makes the command clean and repeatable.

Edit:

```bash
nano ~/.ssh/config
```

Add:

```sshconfig
Host my-ssh-proxy
  HostName your_server_ip
  User username
  ServerAliveInterval 60
  ServerAliveCountMax 3
  ExitOnForwardFailure yes
```

Then start the proxy with:

```bash
ssh -D 1080 -N my-ssh-proxy
```

---

## Step 6 — Server-side hygiene (recommended)

Your DNS privacy now depends on what the server uses for DNS.

On Ubuntu, check current resolvers:

```bash
resolvectl status
```

If you want stronger privacy, consider configuring the server to use:

* a trusted resolver
* DNS over TLS / DNS over HTTPS on the server side (implementation varies by distro and policy)

Also keep the server patched:

```bash
sudo apt update && sudo apt upgrade -y
```

---

## When to use this technique

This approach is useful for:

* Security education and demos (DNS leakage, network visibility)
* Traveling / public Wi-Fi
* Testing apps from a different network egress
* Environments where DoH is blocked locally

It’s not a replacement for:

* endpoint security
* safe browsing practices
* compartmentalization (separate profiles/devices)
* organizational policy compliance

---

## Summary

Using an **SSH SOCKS proxy** lets you browse through a remote machine so that **DNS resolution happens remotely**, reducing DNS leakage on your local network. It’s simple, auditable, and uses widely accepted primitives (SSH + SOCKS5 + browser proxy).

### Quick checklist

* ✅ `ssh -D 1080 -N user@server`
* ✅ Firefox SOCKS v5 → `127.0.0.1:1080`
* ✅ Enable “Proxy DNS when using SOCKS v5”
* ✅ Verify with ipleak/dnsleaktest
* ✅ Consider disabling WebRTC

