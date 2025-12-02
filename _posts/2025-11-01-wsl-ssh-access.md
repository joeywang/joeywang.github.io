---
layout: post
title: "Setting Up OpenSSH on WSL and Enabling Remote Access (Windows
10)"
date: 2025-11-01
tags: [wsl, ssh, openssh, windows10, remote-access]
---
# Setting Up OpenSSH on WSL and Enabling Remote Access (Windows 10)

Running an SSH server inside WSL is a clean way to manage your Linux environment from Windows or other machines on your network. The main work is:

1. Install and configure `openssh-server` in your WSL distro.
2. Make sure `sshd` starts reliably.
3. If you’re on WSL2, forward a Windows port to WSL because WSL2 uses a NATed VM. ([Johngai’s Tech Forge][1])

This guide walks through each step and ends with a secure, persistent remote SSH setup.

---

## Prereqs: Know Your WSL Version

* **WSL 1** shares the Windows network stack. Services you run in WSL1 are reachable on the Windows host IP directly.
* **WSL 2** runs in a lightweight VM with its own virtual NIC (usually 172.x.x.x). Windows can access it via localhost, but other devices **cannot** unless you port-forward. ([Microsoft Learn][2])

Check your WSL version in PowerShell:

```powershell
wsl -l -v
```

---

## Step 1: Install OpenSSH in WSL

Open your WSL terminal:

```bash
sudo apt update
sudo apt install openssh-server openssh-client
```

`openssh-client` lets you SSH *out* from WSL; `openssh-server` lets you SSH *into* WSL. ([Johngai’s Tech Forge][1])

Verify:

```bash
ssh -V
sshd -T | head
```

---

## Step 2: Configure the SSH Server

Edit the server config:

```bash
sudo nano /etc/ssh/sshd_config
```

Recommended minimal changes:

```sshconfig
# Listen on standard port, or change if you want
Port 22

# Listen on all interfaces (good for WSL2)
ListenAddress 0.0.0.0

# Disable root login
PermitRootLogin no

# Password auth optional: keep on for simplicity, off for keys-only
PasswordAuthentication yes
```

* `ListenAddress 0.0.0.0` makes sure `sshd` binds to all interfaces, which helps in WSL2 networking setups. ([Johngai’s Tech Forge][1])
* If you change the port (say to 2222), remember to forward that port later from Windows. ([Johngai’s Tech Forge][1])

Restart `sshd` after edits:

```bash
sudo service ssh restart
# or if systemd is on:
sudo systemctl restart ssh
```

---

## Step 3: Start SSH Automatically

### Case A) Your WSL supports systemd (common now)

WSL supports systemd if enabled in `/etc/wsl.conf`. Microsoft documents this flow. ([Microsoft Learn][3])

Enable systemd:

```bash
sudo nano /etc/wsl.conf
```

Add:

```ini
[boot]
systemd=true
```

Then restart WSL from PowerShell:

```powershell
wsl --shutdown
```

Back in WSL:

```bash
sudo systemctl enable ssh
sudo systemctl start ssh
sudo systemctl status ssh
```

### Case B) No systemd

Start manually:

```bash
sudo service ssh start
sudo service ssh status
```

If you want it to start on shell launch, add to `~/.bashrc` or `~/.profile`:

```bash
sudo service ssh start >/dev/null 2>&1
```

(There are fancier ways, but this is simple and effective.)

---

## Step 4: Allow Authentication (Password or Keys)

### Option 1: Password login

Make sure your WSL user has a password:

```bash
passwd
```

### Option 2: SSH keys (better)

On the machine you connect *from*:

```bash
ssh-keygen -t ed25519
ssh-copy-id your_wsl_user@HOST_ALIAS_OR_IP
```

Then you can disable passwords in `sshd_config` later for stronger security. ([Johngai’s Tech Forge][1])

---

## Step 5: Connect Locally from Windows

### WSL 1

Just SSH to localhost:

```powershell
ssh your_wsl_user@localhost
```

### WSL 2

Windows can still reach WSL2 services on localhost due to automatic localhost forwarding. ([Microsoft Learn][2])

```powershell
ssh your_wsl_user@localhost
```

If you changed the port:

```powershell
ssh -p 2222 your_wsl_user@localhost
```

---

## Step 6: Enable Remote Access from Other Computers (WSL2)

Because WSL2 is NATed, you need Windows to forward a port to the WSL VM. The most common approach uses `netsh interface portproxy`. ([Johngai’s Tech Forge][1])

### 6.1 Get your WSL2 IP

In WSL:

```bash
ip addr show eth0
```

Example result: `172.29.64.5`

### 6.2 Create a port forward on Windows

Open **PowerShell as Administrator**:

```powershell
netsh interface portproxy add v4tov4 `
  listenport=2222 listenaddress=0.0.0.0 `
  connectport=22 connectaddress=172.29.64.5
```

Meaning:
Windows listens on port **2222** and forwards to WSL’s port **22**. ([Johngai’s Tech Forge][1])

### 6.3 Open the Windows Firewall

Still in elevated PowerShell:

```powershell
New-NetFirewallRule -DisplayName "Allow SSH to WSL2" `
  -Direction Inbound -Protocol TCP -Action Allow -LocalPort 2222
```

### 6.4 Connect from another machine

From any LAN device:

```bash
ssh -p 2222 your_wsl_user@<windows_host_ip>
```

---

## Step 7: Make Port Forwarding Survive Reboots

WSL2 IPs can change after reboot/sleep. So you need to re-apply portproxy when the WSL IP changes. This is a known WSL2 behavior. ([Microsoft Learn][2])

A simple pattern:

1. Create a PowerShell script `wsl-ssh-forward.ps1`:

```powershell
$wslIp = (wsl hostname -I).Trim()
netsh interface portproxy reset
netsh interface portproxy add v4tov4 listenport=2222 listenaddress=0.0.0.0 connectport=22 connectaddress=$wslIp
```

2. Run it after reboot, or attach it to Task Scheduler (“At log on”).

---

## Troubleshooting

**Connection refused**

* `sshd` isn’t running:

  ```bash
  sudo service ssh start
  ```

**Windows port forward exists but still can’t connect**

* Check portproxy rules:

  ```powershell
  netsh interface portproxy show all
  ```
* Confirm firewall rule is present.

**WSL2 IP changed**

* Re-run your forwarding script (Step 7).

**sshd won’t start**

* Look at logs:

  ```bash
  sudo journalctl -u ssh --no-pager
  # or without systemd
  sudo tail -n 200 /var/log/auth.log
  ```

---

## Security Notes (Worth Doing)

* Use SSH keys and set:

  ```sshconfig
  PasswordAuthentication no
  ```
* Keep `PermitRootLogin no`.
* Consider changing port from 22 → 2222 to reduce drive-by scans (security by itself is limited, but it lowers noise). ([Johngai’s Tech Forge][1])

---

## Wrap-Up

After these steps, you have:

* OpenSSH installed in WSL
* `sshd` starting consistently
* Windows forwarding a stable port for remote access
* A secure login path via keys or password

It ends up feeling like a small Linux server living inside your Windows 10 Surface—reachable from your couch-laptop, your desktop, or anywhere on your LAN.

If you want, I can adapt this exact article to your current setup (WSL1 vs WSL2, custom port, keys-only, or WAN exposure).

[1]: https://johngai.com/2025/02/27/how-to-setup-and-enable-ssh-on-wsl-and-access-from-other-computers/?utm_source=chatgpt.com "How to Setup and Enable SSH on WSL and Access from Other Computers"
[2]: https://learn.microsoft.com/en-us/windows/wsl/networking?utm_source=chatgpt.com "Accessing network applications with WSL | Microsoft Learn"
[3]: https://learn.microsoft.com/en-us/windows/wsl/systemd?utm_source=chatgpt.com "Use systemd to manage Linux services with WSL"

