---
layout: post
title: "JavaScript Engines: The Heart of Your React Native App"
date: 2025-07-13
tags: ["react-native", "javascript", "hermes", "jsc"]
categories: ["react-native"]
---

## The Heart of Your React Native App: Understanding JavaScript Engines (JSC vs. Hermes)

At the core of every React Native application lies a JavaScript engine. This crucial component is responsible for executing your JavaScript code, translating it into instructions that the native platform (iOS or Android) can understand. For years, **JavaScriptCore (JSC)** was the undisputed standard. However, the landscape has shifted significantly with the advent of **Hermes**, an engine purpose-built by Meta (formerly Facebook) to address the unique performance demands of mobile applications.

This article will delve into both JSC and Hermes, exploring how they work, their impact on your app's performance, and providing practical examples of how to manage them in your React Native projects.

### JavaScriptCore (JSC): The Veteran Engine

Before Hermes, React Native primarily relied on JavaScriptCore. JSC is Apple's open-source JavaScript engine, powering Safari and many other applications within the Apple ecosystem. On Android, React Native shipped with a bundled version of JSC.

**How it Works (Simplified):**

JSC is a "Just-In-Time" (JIT) compilation engine. This means that when your app starts, the JavaScript code is interpreted and then compiled into machine code *during runtime*.

  * **Interpretation:** The engine first reads and understands your JavaScript code line by line.
  * **Compilation (JIT):** Hot code paths (parts of your code that are executed frequently) are identified and compiled into optimized machine code, which can be executed much faster than interpreted code.
  * **Execution:** The compiled machine code is then executed by the device's processor.

**Pros of JSC (Historically):**

  * **Widespread Use:** Being a mature and widely used engine, it was well-tested and understood.
  * **Debugging Familiarity:** Developers were generally familiar with debugging JavaScript code running on a JIT engine.

**Cons of JSC for React Native:**

  * **Slower Startup Times:** The JIT compilation process happens at runtime, contributing to slower application startup, especially for larger apps, as the engine needs to parse, compile, and optimize the JavaScript code on the fly.
  * **Higher Memory Usage:** JIT compilers can consume more memory due to the need to store both the original JavaScript code and its compiled machine code.
  * **Bundle Size Impact:** While not directly related to the engine's size, the way JSC processes JavaScript often meant less aggressive optimizations could be applied to the JavaScript bundle itself.
  * **iOS Limitations:** On iOS, for security reasons, applications are prohibited from using "writable executable memory." This significantly restricts JSC's ability to perform JIT compilation, forcing it to run in an interpreter-only mode for much of its execution, which is less performant.

### Hermes: The Performance Powerhouse

Recognizing the performance bottlenecks with JSC, particularly on lower-end Android devices and due to iOS's JIT restrictions, Meta developed Hermes specifically to optimize React Native application performance. Hermes has been the default engine for new React Native projects since version 0.70+.

**How it Works (Simplified):**

Hermes takes an "Ahead-of-Time" (AOT) compilation approach, with a focus on size, startup time, and memory usage.

  * **Pre-compilation (AOT):** When you build your React Native application for release, Hermes compiles your JavaScript code into highly optimized bytecode *before* the app is even installed on a device. This bytecode is then bundled with your app.
  * **Runtime Execution:** When the app launches, the Hermes engine doesn't need to parse and compile JavaScript on the fly. Instead, it directly loads and executes the pre-compiled bytecode, which is much faster.

**Pros of Hermes:**

  * **Significantly Faster Startup Times:** By moving the compilation step to the build phase, apps launch much quicker, providing a snappier user experience. This is especially noticeable on older or less powerful devices.
  * **Reduced Memory Usage:** Hermes is designed to be very memory-efficient, leading to lower RAM consumption during runtime. This can prevent app crashes on memory-constrained devices and improve overall fluidity.
  * **Smaller App Size:** Hermes can produce smaller JavaScript bundles, contributing to a smaller overall app download size.
  * **Optimized for Mobile:** Its design prioritizes the constraints and requirements of mobile environments.
  * **Improved Debugging (Modern Hermes):** While initially it had some debugging limitations, recent versions of Hermes have significantly improved compatibility with standard debugging tools.

**Cons of Hermes (Historically/Minor):**

  * **Initial Debugging Challenges:** In its early days, debugging Hermes-enabled apps was more complex as it wasn't fully compatible with all features of React Native Debugger or Chrome DevTools. This has largely been resolved.
  * **Limited Browser Compatibility:** Hermes is designed for React Native, not for running in a web browser.
  * **Build Time Increase:** The AOT compilation step adds a small overhead to the app's build time, though the runtime benefits usually far outweigh this.

### Performance Improvements in Practice

The performance improvements offered by Hermes can be quite dramatic:

  * **Startup Time:** Reports show 2x to 3x faster startup times.
  * **Memory Usage:** Up to 30-50% reduction in memory footprint.
  * **App Size:** A noticeable decrease in the size of the JavaScript bundle, leading to smaller app downloads.

These improvements directly translate to a better user experience:

  * Users don't have to wait as long for the app to become interactive.
  * Apps feel more fluid and responsive, with fewer stutters or freezes.
  * Reduced crashes due to out-of-memory errors.

### Example: Managing Hermes in Your React Native Project

As of React Native 0.70+, Hermes is enabled by default for new projects. However, you might want to control when it's enabled (e.g., only for release/QA builds, but not for debug builds for specific debugging workflows).

Here's how you can configure Hermes conditionally.

#### 1\. Enable/Disable Hermes in `gradle.properties` (Android)

In your `android/gradle.properties` file, you'll find:

```properties
# Use this property to enable or disable the Hermes JS engine.
# If set to false, you will be using JSC instead.
hermesEnabled=true
```

This sets the default. Keep it `true` for standard Hermes usage.

#### 2\. Conditional Hermes for Android Build Types (`android/app/build.gradle`)

To enable Hermes only for specific build types (e.g., `release` and `qaRelease`) while disabling it for `debug`:

```gradle
android {
    // ...
    buildTypes {
        release {
            // ... other release configurations
            // Enable Hermes for production release builds
            resValue "boolean", "enableHermes", "true"
        }
        debug {
            // ... other debug configurations
            // Disable Hermes for debug builds (e.g., for specific debugging needs)
            resValue "boolean", "enableHermes", "false"
        }
        // Assuming you have a 'qaRelease' build type defined
        qaRelease {
            // ... similar to release, define your QA specific settings
            // Enable Hermes for QA builds
            resValue "boolean", "enableHermes", "true"
            matchingFallbacks = ['release'] // Fallback to release for missing config
        }
    }
    // ...
}
```

After modifying, clean and rebuild your Android project:

```bash
cd android && ./gradlew clean && cd ..
npx react-native run-android --mode=release # Builds with Hermes
npx react-native run-android --mode=debug   # Builds without Hermes (JSC)
```

#### 3\. Conditional Hermes for iOS Build Configurations (`ios/Podfile`)

For iOS, you modify your `ios/Podfile`. This example assumes you have a `Release` configuration (for production) and a `QARelease` configuration (for QA).

```ruby
require_relative '../node_modules/react-native/scripts/react_native_postinstall'

target 'YourAppName' do
  config = use_native_modules!

  use_react_native!(
    :path => config[:reactNativePath],
    # Enable Hermes only for 'Release' and 'QARelease' configurations
    :hermes_enabled => (ENV['CONFIGURATION'] == 'Release' || ENV['CONFIGURATION'] == 'QARelease'),
    # You might also want to conditionally enable Flipper for debug builds
    :flipper_configuration => FlipperConfiguration.enabled_for_build_configuration(
      ENV['CONFIGURATION'],
      :debug_information => { 'Debug' => true, 'QARelease' => false, 'Release' => false }
    )
  )

  # ... other pods
end
```

After modifying, install your pods:

```bash
cd ios && pod install && cd ..
npx react-native run-ios --configuration Release    # Builds with Hermes
npx react-native run-ios --configuration Debug      # Builds without Hermes (JSC)
```

*(Note: To create a `QARelease` configuration in Xcode, go to your project in Xcode, select the "Info" tab, and under "Configurations," duplicate the `Release` configuration and rename it.)*

### Conclusion

The choice of JavaScript engine is a critical factor in the performance of your React Native application. While JavaScriptCore served its purpose for many years, Hermes has emerged as the clear winner for modern React Native development, offering significant improvements in startup time, memory usage, and app size.

By understanding the strengths of Hermes and knowing how to control its activation in your build process, you can ensure your users enjoy a fast, fluid, and resource-efficient experience, whether they're on the latest flagship device or an older budget smartphone. For most applications, embracing Hermes is no longer just an option, but a recommended best practice.
