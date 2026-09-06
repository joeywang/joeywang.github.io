---
layout: post
title:  "Signed React Native Android APKs from GitHub Actions"
description: "A GitHub Actions pipeline that decodes a base64 keystore from repository secrets and produces a signed React Native Android APK on every push."
date:   2025-08-11 10:00:00 -0400
categories: [DevOps]
tags: [react, android, github-actions, ci]
---

Building and signing a React Native Android release APK by hand is a few fiddly steps you don't want to repeat manually on every push: assemble the release build, sign it with a keystore, hand the artifact off. Doing it in GitHub Actions means every push produces a signed APK without anyone running Gradle locally, and the keystore itself never touches a developer's machine.

## Prerequisites

Before setting up the workflow, you'll need to prepare a few key assets.

1.  **Android Keystore**: You'll need an Android keystore file for signing your release APK; it's required both for app security and for publishing to the Google Play Store. If you don't have one, generate it with the `keytool` command-line utility.

    ```bash
    keytool -genkey -v -keystore my-release-key.keystore -alias my-key-alias -keyalg RSA -keysize 2048 -validity 10000
    ```

    Running this command will prompt you for several details, including a password for your keystore and a password for your key. **Remember these passwords**, as you'll need them later. This will create a file named `my-release-key.keystore`.

2.  **Base64 Encode the Keystore**: For security, we'll store the keystore file as a GitHub secret. Secrets are plain text, so we need to encode the binary keystore file into a string. The best practice is to use **Base64 encoding**.

      * On **macOS/Linux**:

        ```bash
        base64 my-release-key.keystore | tr -d '\n' | tee keystore_base64.txt
        ```

        This command encodes the file and removes any newlines, ensuring the output is a single, continuous string, which is ideal for a secret.

      * On **Windows (PowerShell)**:

        ```powershell
        [Convert]::ToBase64String([IO.File]::ReadAllBytes("my-release-key.keystore")) | Out-File -FilePath keystore_base64.txt -Encoding ascii
        ```

    This will create a file `keystore_base64.txt` containing the encoded keystore string.

-----

## Setting up GitHub Secrets

GitHub Secrets are encrypted environment variables you can use in your workflows, and they're the safest way to hand a CI job passwords and keys.

1.  **Navigate to Repository Settings**: Go to your GitHub repository and click on the "Settings" tab.
2.  **Access Secrets**: In the left sidebar, click on "Secrets and variables" then "Actions".
3.  **Add Repository Secrets**: Click the "New repository secret" button to add each of the following secrets:
      * `RELEASE_KEYSTORE_BASE64`: Copy and paste the entire contents of your `keystore_base64.txt` file here.
      * `RELEASE_STORE_PASSWORD`: The password for your keystore.
      * `RELEASE_KEY_ALIAS`: The alias you gave your key (e.g., `my-key-alias`).
      * `RELEASE_KEY_PASSWORD`: The password for your key.

-----

## The GitHub Actions Workflow File

Create a new file at `.github/workflows/android-build.yml` in your project's root directory. This is where you'll define the build pipeline.

```yaml
name: Build React Native Android

on:
  # The workflow will run on pushes to 'main' branches
  # and on pull requests targeting 'main'.
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

# Jobs are a series of steps that run on a runner machine.
jobs:
  build-android:
    # Use the latest Ubuntu runner, a standard choice for builds.
    runs-on: ubuntu-latest

    # Optional: You can specify an environment for advanced security rules.
    # environment: build

    steps:
      # Step 1: Check out the repository code.
      - name: Checkout repository
        uses: actions/checkout@v4

      # Step 2: Set up the correct Node.js environment.
      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '22'
          cache: 'yarn' # This caches the yarn dependencies to speed up future builds.

      # Step 3: Install all project dependencies.
      - name: Install Yarn dependencies
        run: yarn install --frozen-lockfile

      # Step 4: Set up Java, a requirement for Android builds.
      - name: Set up Java
        uses: actions/setup-java@v3
        with:
          distribution: 'temurin'
          java-version: '17'

      # Step 5: Set up the Android SDK and required build tools.
      - name: Set up Android SDK
        uses: android-actions/setup-android@v3

      # Step 6: Decode the base64-encoded keystore and write it to a file.
      - name: Decode Keystore
        run: |
          echo "${{ secrets.RELEASE_KEYSTORE_BASE64 }}" | base64 -d > android/app/my-release-key.keystore

      # Step 7: Create the keystore.properties file for Gradle.
      - name: Create keystore.properties
        run: |
          echo "storeFile=my-release-key.keystore" > android/keystore.properties
          echo "storePassword=${{ secrets.RELEASE_STORE_PASSWORD }}" >> android/keystore.properties
          echo "keyAlias=${{ secrets.RELEASE_KEY_ALIAS }}" >> android/keystore.properties
          echo "keyPassword=${{ secrets.RELEASE_KEY_PASSWORD }}" >> android/keystore.properties

          # Move the properties file to the correct location for Gradle.
          mkdir -p android/keystores
          mv android/keystore.properties android/keystores/keystore.properties

      # Step 8: Build the Release APK.
      - name: Build Android Release
        run: |
          # Make sure the Gradle wrapper is executable.
          chmod +x ./android/gradlew

          # Use Gradle to assemble the release build.
          cd android && ./gradlew assembleRelease

      # Step 9: Upload the resulting APK as a workflow artifact.
      - name: Upload Release APK
        uses: actions/upload-artifact@v4
        with:
          name: app-release.apk
          path: android/app/build/outputs/apk/release/app-release.apk
```

-----

## What Each Step Is Doing

The checkout, Node, Java, and Android SDK setup steps just build the environment the rest of the job needs. `yarn install --frozen-lockfile` matters more than it looks: it fails the build if `yarn.lock` is out of sync, instead of silently installing something different than what's committed.

The keystore handling is the part worth double-checking if something goes wrong. `base64 -d` turns the secret string back into the binary keystore file, and the `keystore.properties` file it writes is what Gradle actually reads to sign the APK. If the build fails at the `assembleRelease` step, this is almost always where to look first, either a wrong alias or a keystore that didn't decode cleanly.

`upload-artifact` is what makes the APK retrievable afterward: without it, the build succeeds but the output disappears when the runner is torn down.

