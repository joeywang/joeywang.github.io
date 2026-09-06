---
layout: post
title: "Migrating OTP Secrets Out of Google Authenticator"
description: "How to export TOTP secrets from Google Authenticator with the otpauth tool and import them into Authy, Aegis, or 1Password without losing account access."
date: "2025-01-01"
categories: [Security]
tags: [security, otp, cli]
---

<audio controls preload="metadata" src="/assets/audio/otp-migration-summary.ogg">
  Your browser does not support the audio element.
</audio>


Google Authenticator holds your TOTP secrets hostage in one sense: there is an export flow, but it produces a proprietary migration QR code rather than the standard `otpauth://` URLs other apps import. If you want to move to Authy, Aegis, or 1Password, you need to decode that QR code yourself. This post covers the mechanics, and enough of the TOTP background to understand why the secret key is the only thing that matters.

## How TOTP actually works

Each account has a shared secret key. The service generates it, encodes it into a QR code, and your authenticator app stores it at registration. From then on, both sides compute the same code independently:

```
OTP = HMAC-SHA1(secret_key, current_time_interval)
```

- The current time is divided into fixed intervals, typically 30 seconds.
- Both the app and the server run the same HMAC over the same secret and interval.
- Matching output means a valid code. No network round trip is needed, which is why authenticator apps work in airplane mode.

The consequence for migration: whoever holds the secret key can generate valid codes. Migrating an OTP account means moving that secret, nothing more. It also means the exported QR codes are as sensitive as passwords. Do not screenshot them into a synced photo library.

## The migration steps

### 1. Get the otpauth tool

[otpauth](https://github.com/dim13/otpauth) decodes Google's migration QR codes into standard OTP URLs. On macOS, downloaded binaries are quarantined, so clear the attribute before running it:

```sh
sudo xattr -d com.apple.quarantine ./otpauth
```

### 2. Export from Google Authenticator

- Open Google Authenticator.
- Tap the menu and select **Export Accounts**.
- Save the migration QR code it displays.

### 3. Decode the QR code

Feed the QR code image to the tool:

```sh
./otpauth -d /path/to/qr_code.png
```

You get one standard URL per account:

```
otpauth://totp/ServiceName:Username?secret=YOUR_SECRET_KEY&issuer=ServiceName
```

### 4. Import into the new app

Add each account manually in the target app, either by entering the extracted secret key or by rendering the `otpauth://` URL back into a QR code and scanning it.

### 5. Verify before you delete anything

Log in to each service using a code from the new app while the old app still works. Only remove accounts from Google Authenticator after every service has accepted a code from the replacement. Skipping this step is how people lock themselves out.

## The workflow in one picture

```
[Service Provider] ---> [Generates Secret Key] ---> [QR Code]
[User] ---> [Scans QR Code] ---> [Authenticator App]
[Authenticator App] ---> [Generates OTP] ---> [User Inputs OTP]
[Service] ---> [Verifies OTP] ---> [Access Granted]
```

The migration is just the secret key changing hands. Treat the exported QR codes and decoded URLs as credentials: delete them once the import is verified, and keep an offline backup of the secrets somewhere you would trust with your passwords.
