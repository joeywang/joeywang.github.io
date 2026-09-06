---
layout: post
title: "Monitor Cloudflare WARP Status on macOS with launchd"
description: "A launchd-scheduled shell script that detects when Cloudflare WARP reconnects on a company-managed Mac and sends a desktop notification."
date: "2025-02-02"
categories: [Security, DevOps]
tags: [security, macos, automation, networking]
---

<audio controls preload="metadata" src="/assets/audio/zero-trust-monitor-summary.ogg">
  Your browser does not support the audio element.
</audio>

Cloudflare Zero Trust does its job well: it enforces a secure WARP tunnel to the corporate network. The annoyance shows up on a company-managed Mac, where the client re-enables itself automatically and reroutes traffic even after you're off duty. You usually can't disable or uninstall it, so the practical option is visibility: know when it's on, and get notified.

This is a small script that checks WARP's status on a schedule, logs it, and fires a macOS notification when the state changes.

## Why monitor WARP at all

Once WARP is active, it can:

- Slow down personal traffic or conflict with a personal VPN
- Route data through corporate inspection outside work hours
- Interfere with a local firewall, proxy, or service

None of that is fixable if you can't touch the client. A monitor at least tells you what's happening.

## Tools

- `curl` to detect WARP status
- `terminal-notifier` for notifications (cleaner than `osascript`)
- `launchd` to run the check on a schedule
- A log file for the history

## Step 1: The monitoring script

```bash
mkdir -p ~/scripts
nano ~/scripts/check_warp.sh
```

```bash
#!/bin/bash

NOTIFIER="/opt/homebrew/bin/terminal-notifier"  # Adjust for Intel Macs if needed
LOGFILE="$HOME/warp_check.log"

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

echo "$(date): Checking WARP status..." >> "$LOGFILE"

WARP_STATUS=$(curl -s https://www.cloudflare.com/cdn-cgi/trace | grep warp)
echo "$(date): WARP Status: $WARP_STATUS" >> "$LOGFILE"

if [[ "$WARP_STATUS" == "warp=on" ]]; then
    "$NOTIFIER" -title "Zero Trust Detected" -message "WARP is routing your traffic"
    echo "$(date): Notified: WARP ON" >> "$LOGFILE"
else
    "$NOTIFIER" -title "Freedom Mode" -message "WARP is not connected"
    echo "$(date): Notified: WARP OFF" >> "$LOGFILE"
fi
```

```bash
chmod +x ~/scripts/check_warp.sh
```

## Step 2: Install terminal-notifier

```bash
brew install terminal-notifier
which terminal-notifier
```

Update the script path if needed: `/opt/homebrew/bin` on Apple Silicon, `/usr/local/bin` on Intel.

## Step 3: Schedule it with launchd

```bash
nano ~/Library/LaunchAgents/com.user.checkwarp.plist
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.checkwarp</string>

    <key>ProgramArguments</key>
    <array>
        <string>/Users/YOUR_USERNAME/scripts/check_warp.sh</string>
    </array>

    <key>StartInterval</key>
    <integer>600</integer> <!-- every 10 minutes -->

    <key>RunAtLoad</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/tmp/checkwarp.out</string>

    <key>StandardErrorPath</key>
    <string>/tmp/checkwarp.err</string>
</dict>
</plist>
```

Replace `YOUR_USERNAME` with the output of `whoami`, then load it:

```bash
launchctl load ~/Library/LaunchAgents/com.user.checkwarp.plist
```

To stop it: `launchctl unload ~/Library/LaunchAgents/com.user.checkwarp.plist`.

## Step 4: Verify it

- Run the script manually, or wait ~10 minutes for launchd to fire it: `~/scripts/check_warp.sh`
- Tail the log: `tail -f ~/warp_check.log`
- Allow notifications for Terminal/iTerm in System Settings > Notifications

## Optional: disconnect during off-hours

If your policy actually allows it, you can add a disconnect step:

```bash
HOUR=$(date +%H)
if [[ "$HOUR" -ge 18 || "$HOUR" -lt 9 ]]; then
    /Applications/Cloudflare\ WARP.app/Contents/MacOS/Cloudflare\ WARP --disconnect
fi
```

Check first. Some organizations enforce auto-reconnect, and forcing a disconnect against policy is not a great look.

You could take this further and ping an internal hostname to catch Zero Trust routing even when WARP reports itself as off, but that's a separate check worth its own script.

With this in place, you get a log of when WARP was active, a notification when it flips on, and an optional escape hatch for off-hours. That's the ceiling of what's possible without admin rights on the machine, and it's enough to stop being surprised by your own laptop.
