---
layout: post
title: Monitoring Cloudflare Zero Trust & WARP on macOS
date: "2025-02-03"
categories: security cloudflare zero-trust macos
---

## Monitoring Cloudflare Zero Trust & WARP on macOS

This article explores how to detect and respond to Cloudflare WARP and Zero Trust activity on a macOS system — especially useful when you're off-duty but find your corporate WARP client rerouting traffic against your intentions.

### 📌 Goals
- Detect WARP and Zero Trust usage
- Provide lightweight visibility into DNS, routing, and ASN info
- Offer reversible ways to disable routing
- Avoid conflicts with company MDM settings

---

## 🔍 Detecting WARP Status

Use Cloudflare's trace endpoint:

```bash
curl -s https://www.cloudflare.com/cdn-cgi/trace | grep warp
```

Expected outputs:
- `warp=on` → WARP is active
- `warp=off` → WARP is not active

This does **not** indicate if you're still connected to a Zero Trust tunnel.

---

## 🧠 Detecting DNS-over-HTTPS (DoH) Usage

Run:

```bash
scutil --dns
```

Look for Cloudflare DoH endpoints like:

```
https://cloudflare-dns.com/dns-query
```

This shows whether your DNS is going through encrypted resolvers. DoH bypasses traditional tools like `dig` or `nslookup`.

---

## 🌐 Detect Zero Trust Network Routing

Even if WARP is off, you might still be routed through a Zero Trust tunnel. Run:

```bash
curl -s http://whoami.cloudflareclient.com
curl -s https://ipinfo.io
```

Check the returned ASN. If it's Cloudflare (AS13335), you're likely still routed through them.

The most reliable way to verify Zero Trust routing is to check if **internal-only domains resolve**:

```bash
dig internal.corp.example
```

If this resolves, you're likely in the tunnel.

---

## ✅ Lightweight Monitoring Script

```bash
#!/bin/bash

WARP=$(curl -s https://www.cloudflare.com/cdn-cgi/trace | grep warp)
ASN=$(curl -s https://ipinfo.io/org)
DNS=$(scutil --dns | grep "https://")

echo "WARP status: $WARP"
echo "ASN: $ASN"
echo "DoH in use: $DNS"
```

You can run this on a schedule or via `launchd`.

---

## 🔌 Blocking Zero Trust DNS with /etc/hosts

If you can’t disable WARP due to MDM restrictions, you can override DNS locally with `/etc/hosts`. This doesn't kill WARP, but it prevents key services from resolving.

### Step 1: Create a Blocklist
Save as `~/scripts/zero_trust_blocklist.txt`:

```txt
# Zero Trust Block Rules START
127.0.0.1 api.corp.example
127.0.0.1 sso.example.com
127.0.0.1 warp.cloudflareclient.com
# Zero Trust Block Rules END
```

### Step 2: Toggle Script

```bash
#!/bin/bash

HOSTS_FILE="/etc/hosts"
BLOCKLIST="$HOME/scripts/zero_trust_blocklist.txt"

if grep -q "# Zero Trust Block Rules START" "$HOSTS_FILE"; then
    echo "🟢 Unblocking Zero Trust domains..."
    sudo sed -i.bak '/# Zero Trust Block Rules START/,/# Zero Trust Block Rules END/d' "$HOSTS_FILE"
else
    echo "🔴 Blocking Zero Trust domains..."
    sudo cp "$HOSTS_FILE" "$HOSTS_FILE.bak"
    sudo bash -c "cat '$BLOCKLIST' >> '$HOSTS_FILE'"
fi
```

Make it executable:

```bash
chmod +x ~/scripts/toggle_zero_trust_hosts.sh
```

### Step 3: Optional Notifications

Use `terminal-notifier` to show a desktop alert:

```bash
terminal-notifier -title "Zero Trust Hosts" -message "Block mode enabled"
```

### Step 4: Run Off-Hours Automatically

You can use `launchd` to schedule the toggle during off-duty hours. Sample logic:

```bash
HOUR=$(date +%H)
if [[ $HOUR -ge 18 || $HOUR -lt 9 ]]; then
  ~/scripts/toggle_zero_trust_hosts.sh
fi
```

---

## 🧠 Wrap-up

This toolkit gives you visibility and reversible control over Cloudflare Zero Trust behaviors, using safe methods like detection scripts and `/etc/hosts` overrides — without violating system protections.
