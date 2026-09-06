---
layout: post
title: "adb shell pm: Managing Android Packages from the Command Line"
description: "How to use adb shell pm to list, install, uninstall, disable, and inspect Android packages, including removing bloatware without root."
date: 2024-09-15 00:00 +0000
categories: [Engineering]
tags: [android, adb, debugging]
---

<audio controls preload="metadata" src="/assets/audio/adb-shell-pm-summary.ogg">
  Your browser does not support the audio element.
</audio>


Android's settings UI hides most of what the package manager can do. Preinstalled apps you cannot uninstall, disabled system apps you cannot find, no way to see where an APK actually lives. All of that is reachable from a shell. `pm`, the package manager service, is exposed through ADB, and it does not need root for most operations.

## Setup

1. Install ADB on your computer.
2. Enable USB debugging on the device (Settings > Developer options).
3. Connect the device over USB.
4. Run `adb devices` and confirm the device is listed.

## Listing packages

```bash
# List all installed packages
adb shell pm list packages

# Find a specific package
adb shell pm list packages | grep facebook

# Include APK paths and uninstalled packages
adb shell pm list packages -f -u | grep maps
```

The `-u` flag is the one I reach for most: it shows packages that were uninstalled for the current user but still exist on the system partition, which is exactly the state most "removed" bloatware ends up in.

## Installing and reinstalling

```bash
# Install an APK from your computer
adb install path/to/awesome_app.apk

# Reinstall a system app that was removed for this user
adb shell cmd package install-existing com.google.android.apps.maps
```

`install-existing` is the undo button for an over-aggressive debloating session. The APK never left the device; this just makes it visible to your user again.

## Uninstalling

```bash
# Uninstall for user 0 (works on system apps, no root needed)
adb shell pm uninstall --user 0 com.example.bloatware

# Uninstall completely, all users
adb shell pm uninstall com.example.bloatware
```

The `--user 0` form is how you remove carrier and vendor bloatware without root. The app is only removed for that user; the APK stays on the system partition, which is why `install-existing` can bring it back.

## Finding the APK and data

```bash
# Get the APK path for a package
adb shell pm path com.example.app

# List the app's data directory (this one does require root)
adb shell su -c "ls -la /data/data/com.example.app"
```

## Other useful commands

```bash
# Clear app data (useful for troubleshooting)
adb shell pm clear com.example.app

# Disable an app without uninstalling it
adb shell pm disable-user com.example.app

# Re-enable it
adb shell pm enable com.example.app
```

Disabling is often the better move than uninstalling: the app stops running and disappears from the launcher, but nothing is deleted, so reverting is one command.

## Two cautions

Back up anything you care about before touching system apps, and test on a spare device before your daily one. Some packages look like bloatware but are dependencies for things you actually use, and the failure mode is a boot loop, not an error message.
