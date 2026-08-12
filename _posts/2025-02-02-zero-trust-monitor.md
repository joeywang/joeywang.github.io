---
layout: post
title: "🕵️‍♂️ Monitoring Cloudflare Zero Trust (WARP) and Disconnecting on macOS"
description: "Cloudflare Zero Trust is great for enforcing corporate security policies, but if you're using a company-managed device, it can be frustrating when the WARP"
date: "2025-02-02"
categories: security cloudflare zero-trust macos
---

# 🕵️‍♂️ Monitoring Cloudflare Zero Trust (WARP) and Disconnecting on macOS

<audio controls preload="metadata" src="/assets/audio/zero-trust-monitor-summary.ogg">
  Your browser does not support the audio element.
</audio>


Cloudflare Zero Trust is great for enforcing corporate security policies, but if you're using a **company-managed device**, it can be frustrating when the **WARP client re-enables automatically** and reroutes traffic—even while you're off duty.

In this guide, we'll walk through how to:

- ✅ Detect when WARP is active
- 📢 Get real-time alerts via macOS notifications
- ⏱ Run the check automatically at regular intervals
- 📒 Log activity for auditing or debugging
- 🚫 (Optional) Trigger a disconnect or alert when off duty

---

## 🚧 Why You Might Want to Monitor Cloudflare WARP

Cloudflare WARP via Zero Trust automatically enforces a secure VPN tunnel to your organization’s network. This can:

- Slow down personal traffic or VPNs
- Route data through corporate inspection even after work
- Conflict with personal firewall, proxies, or local services

Since **you might not be allowed to disable or uninstall the client** on a corporate Mac, a script that monitors its status and alerts you can give you more visibility—and peace of mind.

---

## 🧰 Tools We'll Use

- `curl` – to detect WARP status
- `terminal-notifier` – to show notifications (better than `osascript`)
- `launchd` – to automate periodic checks on macOS
- Shell scripting – for glue logic
- Logging – to track status changes

---

## 📝 Step 1: Create the Monitoring Script

Create a directory for your scripts:

```bash
mkdir -p ~/scripts
```

Then create `check_warp.sh`:

```bash
nano ~/scripts/check_warp.sh
```

Paste the following:

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

Make it executable:

```bash
chmod +x ~/scripts/check_warp.sh
```

---

## 🛠 Step 2: Install terminal-notifier

```bash
brew install terminal-notifier
```

Confirm the full path:

```bash
which terminal-notifier
```

Update the script path if necessary (`/opt/homebrew/bin` for Apple Silicon, `/usr/local/bin` for Intel).

---

## 🧩 Step 3: Create a `launchd` Job to Run Every 10 Minutes

Create the `.plist` file:

```bash
nano ~/Library/LaunchAgents/com.user.checkwarp.plist
```

Paste:

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

Replace `YOUR_USERNAME` with the result of `whoami`.

Load it:

```bash
launchctl load ~/Library/LaunchAgents/com.user.checkwarp.plist
```

To stop it:

```bash
launchctl unload ~/Library/LaunchAgents/com.user.checkwarp.plist
```

---

## 🔍 Step 4: Verify It’s Working

- Wait ~10 minutes or run the script manually to test:
  ```bash
  ~/scripts/check_warp.sh
  ```

- View logs:
  ```bash
  tail -f ~/warp_check.log
  ```

- Check notifications (allow them for Terminal/iTerm in **System Settings > Notifications**)

---

## (Optional) 🚫 Disconnect WARP on Off-Hours

If your job allows some flexibility, and you're not violating policy, you could add a disconnection step for off-duty hours:

```bash
HOUR=$(date +%H)
if [[ "$HOUR" -ge 18 || "$HOUR" -lt 9 ]]; then
    /Applications/Cloudflare\ WARP.app/Contents/MacOS/Cloudflare\ WARP --disconnect
fi
```

> ⚠️ **Important**: Use this only if you’re certain it’s permitted. Some orgs enforce auto-reconnect policies.

---

## 🔐 Bonus: Detect Network-Level Blocking

You could also ping an internal IP or DNS name to determine if you're being routed through Zero Trust even if WARP is "off." Let me know if you'd like to add that.

---

## ✅ Conclusion

With this setup, you've built a **simple and effective way to monitor WARP connections**, alert yourself when you're routed through Zero Trust, and take action when you're not on the clock.

This method keeps you aware, gives you some autonomy on a locked-down Mac, and respects macOS's security model.
