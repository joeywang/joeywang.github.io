---
layout: post
title: "Android build and debug tips: jenv, ADB, and wireless debugging"
description: "Practical notes on Android build and debug workflow: managing Java versions with jenv, wireless ADB debugging, release signing, and logcat filtering."
date: 2024-11-12 22:26 +0000
categories: [Engineering]
tags: [android, debugging, productivity]
---

<audio controls preload="metadata" src="/assets/audio/complete-guide-to-android-development-build-and-debug-tips-2024-11-10-summary.ogg">
  Your browser does not support the audio element.
</audio>


A few of the environment quirks that come up repeatedly in Android development: juggling JDK versions, getting ADB to talk to a device over WiFi instead of a cable, and building release APKs without recreating the signing setup from memory each time.

## Java version management with jenv

Android tooling is picky about JDK version, and juggling that against whatever else needs a different JDK is easier with jenv than with manually edited `JAVA_HOME` exports:

```bash
brew install openjdk@11
brew install jenv
```

```bash
# ~/.zshrc or ~/.bashrc
export PATH="$HOME/.jenv/bin:$PATH"
eval "$(jenv init -)"
```

```bash
jenv add /opt/homebrew/opt/openjdk@11/libexec/openjdk.jdk/Contents/Home
jenv versions
jenv global 11.0
jenv local 11.0   # per-project override
```

## USB and wireless debugging

Enable Developer Options (Settings → About Phone → tap Build Number seven times), then USB Debugging under Developer Options. Confirm the device shows up:

```bash
adb devices
adb shell getprop ro.product.model
```

Wireless debugging still needs a USB cable for the initial handshake:

```bash
adb tcpip 5555
adb shell ip addr show wlan0
adb connect <device-ip>:5555
adb devices
```

For React Native, forward Metro's port back to the device instead of relying on the WiFi connection for bundle serving:

```bash
npx react-native start
adb reverse tcp:8081 tcp:8081
```

## Debug and release builds

```bash
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk
```

Release builds need signing configured once, in `android/app/keystore.properties`:

```properties
storeFile=your-key.keystore
storePassword=your-store-password
keyAlias=your-key-alias
keyPassword=your-key-password
```

```bash
./gradlew assembleRelease
cd android/app/build/outputs/apk/release
adb install app-release.apk
```

## Logs and common failures

```bash
adb logcat | grep "com.yourpackage"
adb logcat *:E                        # errors only
adb logcat > logfile.txt
```

Two failure modes come up often enough to have a standard fix. Metro serving stale bundles:

```bash
npx react-native start --reset-cache
cd android && ./gradlew clean
```

And ADB losing the device after a sleep/wake cycle:

```bash
adb kill-server
adb start-server
```

## Memory profiling

Android Studio's Profiler (View → Tool Windows → Profiler) covers most of this visually. From the command line:

```bash
adb shell dumpsys meminfo <package-name>
adb shell am dumpheap <process-name> /data/local/tmp/heap.hprof
```

None of these are exotic. They're just the handful of commands that are easy to forget between the times you actually need them.
