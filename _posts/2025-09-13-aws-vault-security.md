---
layout: post
title:  "Securing AWS Credentials: aws-vault vs 1Password"
description: "Storing long-lived AWS access keys in ~/.aws/credentials is a common anti-pattern; aws-vault and the 1Password AWS Shell Plugin both fix it with short-lived STS tokens."
date:   2025-09-13 10:00:00 -0400
categories: [Security]
tags: [aws, security, devops]
---

<audio controls preload="metadata" src="/assets/audio/aws-vault-security-summary.ogg">
  Your browser does not support the audio element.
</audio>

Storing long-lived AWS access keys directly in `~/.aws/credentials` is a common anti-pattern, and it's a bigger risk than it looks: a leaked key doesn't expire on its own, and there's nothing stopping it from sitting in a laptop backup or a shell history file for years. `aws-vault` and the 1Password AWS Shell Plugin both fix this by generating short-lived STS credentials on demand instead of reading a long-lived key off disk every time. This covers setting up both and where each one fits.

## The security model both tools rely on

  * **Never store long-lived credentials on disk unencrypted.** Hardcoding access keys and secret keys in plain text files is the actual vulnerability both tools exist to close.
  * **Use short-lived credentials (STS).** AWS Security Token Service issues temporary access key, secret key, and session token triples with a limited lifespan, which shrinks the window an attacker gets if credentials leak. Both tools generate these behind the scenes.
  * **Enforce MFA on IAM users.** Even if an attacker gets the primary credentials, they can't assume roles or take sensitive actions without the MFA code.
  * **Grant least privilege**, both to the base IAM user and to any role it can assume.
  * **Unlock secrets through the OS's own authentication** (Touch ID, Face ID, system password) instead of typing passwords into a terminal where they end up in scrollback or history.
  * **Scope credentials to the process that needs them**, and let them expire once that process ends.

## Option 1: Securing AWS Credentials with `aws-vault`

`aws-vault` provides a convenient way to store your AWS IAM user credentials securely in your operating system's native secret storage (like macOS Keychain, Windows Credential Manager, or Linux's `pass` or Secret Service). It then uses these long-lived credentials to fetch temporary STS tokens, which are injected into your shell or specific commands.

### `aws-vault` Security Principles:

  * **Encrypted Storage:** Long-term credentials are encrypted at rest using OS-native secure storage.
  * **STS Token Generation:** Fetches temporary, short-lived STS credentials for every `aws-vault exec` session.
  * **MFA Support:** Prompts for MFA codes when required for STS operations.
  * **Environment Variable Injection:** Credentials are injected as environment variables directly into the executed command's process, minimizing exposure.

### Step-by-Step `aws-vault` Setup

#### 1\. Install `aws-vault`

**macOS (Homebrew):**

```bash
brew install aws-vault
```

**Linux (from source or package manager):** Refer to the [official `aws-vault` documentation](https://github.com/99designs/aws-vault#install) for details, as installation methods vary by distribution. For example, using `go install`:

```bash
go install github.com/99designs/aws-vault@latest
```

#### 2\. Add Your First AWS Credentials

Instead of putting your IAM user's Access Key and Secret Key into `~/.aws/credentials`, you'll add them directly to `aws-vault`'s secure storage.

```bash
aws-vault add my-iam-user-profile
```

You will be prompted to enter your AWS Access Key ID and Secret Access Key. `aws-vault` will then store these securely.

#### 3\. Configure MFA (Strongly Recommended)

If your IAM user requires MFA (and it should), `aws-vault` can manage the MFA token. First, add the ARN of your MFA device to your `~/.aws/config` file:

```ini
# ~/.aws/config

[profile my-iam-user-profile]
mfa_serial = arn:aws:iam::123456789012:mfa/my-iam-user
```

Replace `123456789012` with your AWS account ID and `my-iam-user` with your IAM user name.

#### 4\. Using `aws-vault` for Single Commands

To execute a single AWS CLI command with temporary credentials from your profile:

```bash
aws-vault exec my-iam-user-profile -- aws sts get-caller-identity
```

  * **macOS/Windows:** Your OS's secure credential prompt (e.g., Keychain Access dialog) will appear, asking for permission to access the stored credentials.
  * **MFA:** If MFA is configured, you'll be prompted to enter your MFA code in the terminal.
  * `aws-vault` then fetches temporary STS credentials and injects them into the `aws sts get-caller-identity` command.

#### 5\. Using `aws-vault` for a Shell Session

For a longer working session, you can open a new shell with temporary credentials:

```bash
aws-vault exec my-iam-user-profile
```

This will launch a new shell (e.g., `bash` or `zsh`) where the environment variables for `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` are set. These credentials are valid for a default period (e.g., 1 hour), after which you'll need to re-authenticate or renew them.

#### 6\. Assuming Roles with `aws-vault`

For multi-account or role-based access, you combine `aws-vault` with your `~/.aws/config` file:

```ini
# ~/.aws/config

[profile my-base-profile]
# This is the IAM user profile that has permissions to assume roles
# The credentials for this profile are stored in aws-vault

[profile dev-admin]
role_arn = arn:aws:iam::123456789012:role/DeveloperAdmin
source_profile = my-base-profile # Reference the profile stored in aws-vault
region = us-east-1

[profile prod-readonly]
role_arn = arn:aws:iam::987654321098:role/ReadOnlyAccess
source_profile = my-base-profile
region = us-west-1
```

Now, to assume a role:

```bash
aws-vault exec dev-admin -- aws s3 ls
```

This command will:

1.  Prompt for access to `my-base-profile`'s credentials (and MFA if configured).
2.  Use those to assume the `dev-admin` role.
3.  Execute `aws s3 ls` with the temporary credentials of the `dev-admin` role.

## Option 2: Enhanced Security with 1Password AWS Shell Plugin

For users already invested in 1Password, the official AWS Shell Plugin uses 1Password's secure storage and biometric authentication (Touch ID/Face ID) to manage AWS credentials directly, with no separate credential store or manual keychain unlock step.

### 1Password AWS Shell Plugin Security Principles:

  * **Centralized Secure Storage:** Long-term AWS credentials live exclusively within your encrypted 1Password vault.
  * **Biometric Authentication:** Uses Touch ID/Face ID (or your 1Password master password) to unlock credentials directly from 1Password.
  * **STS Token Generation:** Automatically fetches temporary STS credentials for AWS CLI commands.
  * **Integrated MFA:** Automatically retrieves the TOTP code for MFA from your 1Password item.
  * **No Credentials on Disk:** Long-term AWS credentials are never written to disk outside your 1Password vault.

### Step-by-Step 1Password AWS Shell Plugin Setup

#### Prerequisites:

  * **1Password Desktop App:** Must be installed, running, and signed in to your account.
  * **1Password CLI (`op`):** Install via Homebrew (`brew install 1password-cli`) or your preferred method.
  * **`op` App Integration:** Ensure the `op` CLI is integrated with your desktop app. Check `op signin` if you're unsure.
  * **Biometrics Enabled:** In your 1Password desktop app settings, ensure "Integrate with 1Password CLI" is enabled under Developer, and "Unlock with Touch ID" (or equivalent) is enabled under Security.
  * **AWS CLI:** Installed and available in your PATH.

#### 1\. Initialize the Plugin

Open your terminal and run the setup wizard:

```bash
op plugin init aws
```

#### 2\. Store AWS Credentials in 1Password

The wizard will guide you to:

  * **Import:** If your credentials are in `~/.aws/credentials`, the wizard can import them into a new "Login" item in your 1Password vault. **This is the recommended approach.**
  * **Select:** If you already have an AWS credential item in 1Password, you can choose it.

**Important:** Once imported, **delete your long-lived AWS credentials from `~/.aws/credentials`**. This file should remain empty or only contain profile stubs.

#### 3\. Configure Multi-Factor Authentication (MFA)

If your AWS IAM user requires MFA (and it should), ensure your 1Password Login item for AWS credentials includes a "One-Time Password" field. The wizard can help you set this up if it's missing.

#### 4\. Define Credential Scope

The wizard will ask when these credentials should be used. Common options include:

  * **"Prompt me for each new terminal session"**: Requires a biometric approval once per shell session. This is generally the **most secure and recommended option.**
  * "Use automatically when in this directory or subdirectories": Useful for specific projects.
  * "Use as global default on my system": Applies the credentials by default, but less secure than per-session prompts.

#### 5\. Source the Plugin Script

The wizard will output a command similar to this. Execute it and add it to your shell's configuration file (e.g., `~/.zshrc`, `~/.bashrc`):

```bash
echo 'source ~/.config/op/plugins.sh' >> ~/.zshrc
source ~/.config/op/plugins.sh
```

This script sets up aliases and environment variables so that your `aws` commands are intercepted and handled by the 1Password plugin.

#### 6\. Test and Authenticate with Biometrics

Now, run any AWS CLI command:

```bash
aws sts get-caller-identity
```

**Expected Behavior:**

  * **A system biometric prompt (Touch ID/Face ID) will appear.**
  * Upon successful authentication, the 1Password plugin retrieves your AWS Access Key, Secret Key, and MFA TOTP code.
  * It then uses these to generate temporary STS credentials, which are used to execute your AWS CLI command.
  * The credentials are short-lived, enhancing security.

#### 7\. Assuming Roles with 1Password Plugin

Like `aws-vault`, the 1Password plugin works directly with AWS profiles defined in `~/.aws/config`:

```ini
# ~/.aws/config

[profile my-base-user]
# This profile represents the IAM user whose credentials are in 1Password.
# DO NOT put access_key_id or secret_access_key here.

[profile dev-admin]
role_arn = arn:aws:iam::123456789012:role/DeveloperAdmin
source_profile = my-base-user # Link back to the 1Password-backed profile
region = us-east-1

[profile prod-readonly]
role_arn = arn:aws:iam::987654321098:role/ReadOnlyAccess
source_profile = my-base-user
region = us-west-1
```

To assume a role:

```bash
aws s3 ls --profile dev-admin
```

This will trigger the biometric prompt, fetch your `my-base-user` credentials from 1Password, use them to assume the `dev-admin` role via STS, and then execute the S3 command.

## Choosing one

Pick `aws-vault` if you want a standalone, open-source tool scoped to AWS, don't already use 1Password for credentials, or need a specific backend like `pass` on Linux. Pick the 1Password plugin if you're already centralizing secrets there and want MFA and STS token generation handled from that single source rather than a second tool.

Either way, the point isn't the tool, it's getting long-lived keys off disk. If your team is still pasting access keys into `~/.aws/credentials`, that's the actual fix to make first.
