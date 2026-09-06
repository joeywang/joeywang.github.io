---
layout: post
title: "Optimizing Android Builds in GitHub Actions"
description: "Android builds in GitHub Actions run 10-30 minutes unoptimized; layered Gradle and Yarn caching plus scoped environment secrets get that down to a few minutes."
date: 2025-08-11
categories: [DevOps]
tags: [android, github-actions, ci, devops, performance]
---

<audio controls preload="metadata" src="/assets/audio/android-build-in-github-actions-summary.ogg">
  Your browser does not support the audio element.
</audio>

An unoptimized Android build in GitHub Actions takes 10 to 30 minutes: large dependency trees, Java/Kotlin compilation, APK signing, and (for instrumented tests) emulator startup all add up. That's slow enough to change how a team works, since nobody wants to wait half an hour to find out a PR broke the build. Caching and scoped secrets fix most of it.

## Scoping secrets with GitHub Actions environments

Signing keys and credentials shouldn't be repository-wide secrets available to every job. GitHub Actions environments let you scope them to just the jobs that need them.

### Creating Your Build Environment

1. Navigate to your GitHub repository
2. Click on the **Settings** tab
3. In the left sidebar, select **Environments**
4. Click the **New environment** button and name it `android-build`
5. Add your secrets to this environment:
   - `RELEASE_KEYSTORE_BASE64`
   - `RELEASE_STORE_PASSWORD`
   - `RELEASE_KEY_ALIAS`
   - `RELEASE_KEY_PASSWORD`

### Linking Your Workflow to the Environment

To access these secrets, you need to link your workflow job to the environment:

```yaml
jobs:
  build-android:
    runs-on: ubuntu-latest
    environment: android-build

    steps:
      # Your build steps here
```

This approach ensures that sensitive data is only available to jobs that explicitly require it, following the principle of least privilege.

## Optimizing Build Performance with Caching

Android builds benefit from stacking several caching layers rather than relying on just one.

### Caching Node Dependencies

If you're building a React Native app or using Node.js tools:

```yaml
- name: Set up Node.js with Yarn caching
  uses: actions/setup-node@v4
  with:
    node-version: '18'
    cache: 'yarn'

- name: Install Yarn dependencies
  run: yarn install --frozen-lockfile
```

### Caching Gradle Dependencies

For Android builds, Gradle dependencies are a major time sink:

```yaml
{% raw %}
- name: Set up Gradle caching
  uses: actions/cache@v4
  with:
    path: |
      ~/.gradle/caches
      ~/.gradle/wrapper
    key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
    restore-keys: |
      ${{ runner.os }}-gradle-
{% endraw %}
```

### Caching Build Outputs

Cache intermediate build artifacts to avoid redundant compilation:

```yaml
{% raw %}
- name: Cache build outputs
  uses: actions/cache@v4
  with:
    path: |
      android/app/build
      !android/app/build/outputs/apk
    key: ${{ runner.os }}-android-build-${{ hashFiles('android/app/src/main/AndroidManifest.xml', 'android/app/build.gradle') }}
{% endraw %}
```

## Complete Workflow Example

Here's a comprehensive workflow that incorporates all the optimizations:

```yaml
{% raw %}
name: Android Build

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build-android:
    runs-on: ubuntu-latest
    environment: android-build

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'

      - name: Set up Node.js (for React Native)
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'yarn'

      - name: Install Node dependencies
        run: yarn install --frozen-lockfile

      - name: Cache Gradle wrapper
        uses: actions/cache@v4
        with:
          path: ~/.gradle/wrapper
          key: ${{ runner.os }}-gradle-wrapper-${{ hashFiles('android/gradle/wrapper/gradle-wrapper.properties') }}

      - name: Cache Gradle dependencies
        uses: actions/cache@v4
        with:
          path: ~/.gradle/caches
          key: ${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', 'android/gradle/wrapper/gradle-wrapper.properties', 'android/build.gradle') }}
          restore-keys: |
            ${{ runner.os }}-gradle-

      - name: Decode Keystore
        run: |
          echo "${{ secrets.RELEASE_KEYSTORE_BASE64 }}" | base64 -d > android/app/release-key.keystore

      - name: Create keystore.properties
        run: |
          echo "storeFile=release-key.keystore" > android/keystore.properties
          echo "storePassword=${{ secrets.RELEASE_STORE_PASSWORD }}" >> android/keystore.properties
          echo "keyAlias=${{ secrets.RELEASE_KEY_ALIAS }}" >> android/keystore.properties
          echo "keyPassword=${{ secrets.RELEASE_KEY_PASSWORD }}" >> android/keystore.properties

      - name: Build Android Release
        run: |
          cd android
          ./gradlew assembleRelease --daemon --parallel --configure-on-demand

      - name: Upload APK
        uses: actions/upload-artifact@v4
        with:
          name: app-release.apk
          path: android/app/build/outputs/apk/release/app-release.apk
{% endraw %}
```

## Advanced Optimization Techniques

### Parallel Builds

For multi-module projects, you can parallelize builds:

```yaml
- name: Build modules in parallel
  run: |
    cd android
    ./gradlew :module1:assembleRelease :module2:assembleRelease --parallel
```

### Build Cache with Gradle

Enable Gradle's built-in build cache:

```yaml
- name: Setup Gradle Build Cache
  run: |
    mkdir -p ~/.gradle
    echo "org.gradle.caching=true" >> ~/.gradle/gradle.properties
    echo "org.gradle.parallel=true" >> ~/.gradle/gradle.properties
    echo "org.gradle.configureondemand=true" >> ~/.gradle/gradle.properties
```

### Conditional Builds

Only build on certain branches or conditions:

```yaml
jobs:
  build-android:
    if: github.ref == 'refs/heads/main' || contains(github.event.pull_request.labels.*.name, 'build-android')
    # ... rest of the job
```

## Security Checklist

Never commit secrets to the repository. Scope them to environments instead of leaving them repository-wide. Rotate signing keys and passwords on a schedule, not just after an incident. Limit what permissions the workflow itself has, and keep protected branches on so nobody bypasses the pipeline with a direct push.

## Monitoring and Debugging

For troubleshooting build issues:

```yaml
- name: Debug information
  run: |
    echo "Java version:"
    java -version
    echo "Node version:"
    node --version
    echo "Yarn version:"
    yarn --version
    echo "Gradle version:"
    cd android && ./gradlew --version
```

## The trade-off

Scoped environments and multi-layered caching (Gradle wrapper, Gradle dependencies, build outputs, Yarn) get most teams from 20+ minutes down to a few. The remaining cost is cache invalidation: a change to `build.gradle` or the wrapper properties busts the cache key on purpose, and that's the one build where you pay the full price again. That's a feature, not a bug, since a stale Gradle cache is a worse failure mode than a slow build.