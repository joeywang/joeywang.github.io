---
layout: post
title: 'Complete Guide to Android Development: Build and Debug Tips 2024-11-10'
date: 2024-11-12 22:26 +0000
categories: Android
tags: [android, build, debug]
---

# Complete Guide to Android Development: Build and Debug Tips

This comprehensive guide covers essential tips and techniques for Android development, including Java environment setup, USB debugging, wireless debugging, and build management.

## Setting Up Your Development Environment

### Java Version Management with jenv

Managing multiple Java versions is crucial for Android development. Here's how to set it up:

1. Install OpenJDK and jenv:
```bash
# Install OpenJDK 11 (recommended for Android development)
brew install openjdk@11

# Install jenv for Java version management
brew install jenv
```

2. Configure your shell environment (add to `~/.zshrc` or `~/.bashrc`):
```bash
export PATH="$HOME/.jenv/bin:$PATH"
eval "$(jenv init -)"
```

3. Add Java versions to jenv:
```bash
# Add OpenJDK 11
jenv add /opt/homebrew/opt/openjdk@11/libexec/openjdk.jdk/Contents/Home

# Verify installation
jenv versions

# Set global Java version
jenv global 11.0

# Set local version for a specific project
jenv local 11.0
```

## Android Debugging Options

### USB Debugging

1. Enable Developer Options on your Android device:
   - Go to Settings → About Phone
   - Tap "Build Number" seven times
   - Developer Options will appear in Settings

2. Enable USB Debugging:
   - Go to Settings → Developer Options
   - Enable "USB Debugging"
   - Connect your device via USB
   - Accept the debugging authorization prompt on your device

3. Verify connection:
```bash
# List connected devices
adb devices

# Check detailed device information
adb shell getprop ro.product.model
```

### Wireless Debugging (Over WiFi)

1. Connect via USB first, then enable wireless debugging:
```bash
# Ensure device and computer are on same network
# Connect device via USB

# Enable TCP/IP mode on default port (5555)
adb tcpip 5555

# Get device IP address
adb shell ip addr show wlan0

# Connect to device wirelessly
adb connect <device-ip>:5555

# Verify connection
adb devices
```

2. For React Native development:
```bash
# Start Metro bundler
npx react-native start

# Forward connection from mobile to local
adb reverse tcp:8081 tcp:8081
```

## Build Management

### Debug Builds

1. Using Android Studio:
   - Open your project in Android Studio
   - Select "Debug" configuration
   - Click "Run" (⌘R on Mac, F5 on Windows)

2. Using Command Line:
```bash
# Build debug APK
./gradlew assembleDebug

# Install on connected device
adb install app/build/outputs/apk/debug/app-debug.apk
```

### Release Builds

1. Configure signing:
   - Create `android/app/keystore.properties`:
```properties
storeFile=your-key.keystore
storePassword=your-store-password
keyAlias=your-key-alias
keyPassword=your-key-password
```

2. Build release version:
```bash
# Generate release APK
./gradlew assembleRelease

# Location of generated APK
cd android/app/build/outputs/apk/release
```

3. Test release build:
```bash
# Install release version
adb install app-release.apk
```

## Common Debugging Tips

### Logcat Filtering

```bash
# View logs for specific package
adb logcat | grep "com.yourpackage"

# Filter by log level
adb logcat *:E  # Show only errors

# Save logs to file
adb logcat > logfile.txt
```

### Common Issues and Solutions

1. Metro Bundler Issues:
```bash
# Clear Metro bundler cache
npx react-native start --reset-cache

# Clear Gradle cache
cd android && ./gradlew clean
```

2. Device Connection Issues:
```bash
# Reset ADB
adb kill-server
adb start-server

# Restart device USB debugging
# Toggle USB debugging off and on in device settings
```

## Performance Optimization

### Memory Profiling

1. Using Android Studio:
   - Open Android Studio
   - Go to View → Tool Windows → Profiler
   - Select your running app
   - Monitor memory usage in real-time

2. Using Command Line:
```bash
# Dump memory info
adb shell dumpsys meminfo <package-name>

# Capture heap dump
adb shell am dumpheap <process-name> /data/local/tmp/heap.hprof
```

## Additional Resources

- [Android Developer Documentation](https://developer.android.com/)
- [React Native Documentation](https://reactnative.dev/)
- [Android Studio Guide](https://developer.android.com/studio/intro)
- [ADB Command Line Tools](https://developer.android.com/studio/command-line/adb)
