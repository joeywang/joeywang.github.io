---
layout: post
title: "Detecting Cloudflare Zero Trust Beyond the WARP Flag"
description: "WARP can report itself as off while Zero Trust still routes your Mac's traffic; here is how to check DNS, ASN, and DoH to find out for sure."
date: "2025-02-03"
categories: [Security, DevOps]
tags: [security, macos, networking, dns]
---

<audio controls preload="metadata" src="/assets/audio/zero-trust-monitor-disconnect-summary.ogg">
  Your browser does not support the audio element.
</audio>

Checking whether WARP is "on" only answers half the question. A Mac can still be routed through a Zero Trust tunnel while `warp=off`, and the reverse trip - confirming you're actually off the corporate network - takes a few more checks: DNS, ASN, and whether internal domains still resolve.

## Detecting WARP status

```bash
curl -s https://www.cloudflare.com/cdn-cgi/trace | grep warp
```

`warp=on` means WARP is active, `warp=off` means it isn't. It says nothing about whether you're still inside a Zero Trust tunnel through some other path.

## Detecting DNS-over-HTTPS usage

```bash
scutil --dns
```

Look for a Cloudflare DoH endpoint such as `https://cloudflare-dns.com/dns-query`. If your DNS is going through an encrypted resolver, tools like `dig` and `nslookup` won't show you what's actually being resolved.

## Detecting Zero Trust routing directly

Even with WARP off, you can still be routed through Zero Trust. Check the ASN:

```bash
curl -s http://whoami.cloudflareclient.com
curl -s https://ipinfo.io
```

If the ASN comes back as Cloudflare (AS13335), you're likely still routed through them. The more reliable test is whether internal-only domains resolve at all:

```bash
dig internal.corp.example
```

If that resolves, you're in the tunnel, regardless of what the WARP flag says.

## A lightweight monitoring script

```bash
#!/bin/bash

WARP=$(curl -s https://www.cloudflare.com/cdn-cgi/trace | grep warp)
ASN=$(curl -s https://ipinfo.io/org)
DNS=$(scutil --dns | grep "https://")

echo "WARP status: $WARP"
echo "ASN: $ASN"
echo "DoH in use: $DNS"
```

Run it on a schedule via `launchd` if you want a standing check rather than a one-off.

## Blocking Zero Trust DNS with /etc/hosts

If MDM restrictions mean you can't touch WARP itself, you can override DNS locally with `/etc/hosts`. This doesn't kill WARP, but it stops key services from resolving.

### Step 1: create a blocklist

Save as `~/scripts/zero_trust_blocklist.txt`:

```txt
# Zero Trust Block Rules START
127.0.0.1 api.corp.example
127.0.0.1 sso.example.com
127.0.0.1 warp.cloudflareclient.com
# Zero Trust Block Rules END
```

### Step 2: a toggle script

```bash
#!/bin/bash

HOSTS_FILE="/etc/hosts"
BLOCKLIST="$HOME/scripts/zero_trust_blocklist.txt"

if grep -q "# Zero Trust Block Rules START" "$HOSTS_FILE"; then
    echo "Unblocking Zero Trust domains..."
    sudo sed -i.bak '/# Zero Trust Block Rules START/,/# Zero Trust Block Rules END/d' "$HOSTS_FILE"
else
    echo "Blocking Zero Trust domains..."
    sudo cp "$HOSTS_FILE" "$HOSTS_FILE.bak"
    sudo bash -c "cat '$BLOCKLIST' >> '$HOSTS_FILE'"
fi
```

```bash
chmod +x ~/scripts/toggle_zero_trust_hosts.sh
```

### Step 3: optional notification

```bash
terminal-notifier -title "Zero Trust Hosts" -message "Block mode enabled"
```

### Step 4: run it off-hours automatically

```bash
HOUR=$(date +%H)
if [[ $HOUR -ge 18 || $HOUR -lt 9 ]]; then
  ~/scripts/toggle_zero_trust_hosts.sh
fi
```

None of this disables WARP. It gives you visibility into whether you're actually routed through Zero Trust, and a reversible way to block specific domains when the client won't let you disconnect outright.
