---
layout: post
title: "JavaScript Engines in React Native: JSC vs. Hermes"
description: "React Native's default JS engine moved from JSC to Hermes for faster startup and lower memory use, and here is how to control which one your build uses."
date: 2025-07-13
tags: [react, android, javascript, hermes, performance]
categories: [Engineering]
---

Every React Native app runs its JavaScript through an engine that turns your code into instructions the native platform understands. For years that engine was JavaScriptCore. Since React Native 0.70, it has been Hermes by default, and the switch is not cosmetic: it changes when your code gets compiled and how much memory your app burns at startup.

### JavaScriptCore: the veteran engine

JSC is Apple's JIT engine, the same one that powers Safari. React Native shipped with it on both iOS and Android for years, and most developers who worked with the platform in its early days debugged against it without a second thought.

JSC compiles at runtime: it interprets your code, profiles which paths run often, and compiles those hot paths into machine code as the app runs. That works fine in a browser tab that stays open a while. It works less well for a mobile app that needs to be interactive within a second or two of a cold start, because the compilation cost gets paid on every single launch.

On iOS the problem is worse. Apps aren't allowed to mark memory both writable and executable, which is exactly what JIT compilation needs. JSC has to fall back to interpreter-only mode for much of its execution on iOS, giving up most of the performance a JIT would normally buy.

### Hermes: compile ahead, run fast

Hermes takes the opposite approach: it compiles your JavaScript to bytecode at build time, not at runtime. When the app launches, there's no parsing or compiling left to do. The engine loads the bytecode and starts executing it immediately.

That one design decision is why Hermes apps start faster, particularly on older or lower-end Android devices where JSC's JIT warmup was most painful. It also uses less memory at runtime, since Hermes never has to hold both source and compiled machine code at once, and it tends to produce a smaller JavaScript bundle. Meta's published numbers put startup improvements at 2x to 3x and memory footprint reductions of 30 to 50 percent, which roughly matches what most teams report after migrating.

The trade-off is a slightly longer build, since the compilation step now happens ahead of time instead of never. Debugging support was rough in Hermes's early releases; it has since caught up with standard tooling.

### Controlling Hermes per build

Hermes is on by default for new projects, but you can still turn it off for a specific build type, which is useful if you're debugging an issue that only reproduces under JSC.

#### Android

`android/gradle.properties` sets the default:

```properties
# Use this property to enable or disable the Hermes JS engine.
# If set to false, you will be using JSC instead.
hermesEnabled=true
```

To vary it by build type, set a resource value in `android/app/build.gradle`:

```gradle
android {
    buildTypes {
        release {
            resValue "boolean", "enableHermes", "true"
        }
        debug {
            resValue "boolean", "enableHermes", "false"
        }
        qaRelease {
            resValue "boolean", "enableHermes", "true"
            matchingFallbacks = ['release']
        }
    }
}
```

```bash
cd android && ./gradlew clean && cd ..
npx react-native run-android --mode=release # Hermes
npx react-native run-android --mode=debug   # JSC
```

#### iOS

Set `hermes_enabled` conditionally in `ios/Podfile`:

```ruby
require_relative '../node_modules/react-native/scripts/react_native_postinstall'

target 'YourAppName' do
  config = use_native_modules!

  use_react_native!(
    :path => config[:reactNativePath],
    :hermes_enabled => (ENV['CONFIGURATION'] == 'Release' || ENV['CONFIGURATION'] == 'QARelease'),
    :flipper_configuration => FlipperConfiguration.enabled_for_build_configuration(
      ENV['CONFIGURATION'],
      :debug_information => { 'Debug' => true, 'QARelease' => false, 'Release' => false }
    )
  )
end
```

```bash
cd ios && pod install && cd ..
npx react-native run-ios --configuration Release    # Hermes
npx react-native run-ios --configuration Debug      # JSC
```

To create a `QARelease` configuration in Xcode: open the project's Info tab, and under Configurations, duplicate `Release` and rename it.

### The judgment

Hermes isn't a marginal tweak, it's a different compilation model built for the constraints mobile actually has: cold starts, limited memory, and no JIT on iOS. Unless you have a specific reason to stay on JSC, such as a debugging workflow that depends on it, there's no case left for keeping it as your default engine.
