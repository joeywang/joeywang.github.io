---
layout: post
title: "OpenSSH on WSL: enabling remote SSH access on Windows 10"
date: 2025-11-01
tags: [wsl, ssh, windows, networking, linux]
categories: [DevOps]
description: "Install and configure OpenSSH inside WSL2, enable systemd, and forward a Windows port so you can SSH into your WSL environment from anywhere on your LAN."
---
<audio controls preload="metadata" src="/assets/audio/wsl-ssh-access-summary.ogg">
  Your browser does not support the audio element.
</audio>

Running an SSH server inside WSL turns it into a small Linux box you can reach from the rest of your network, not just from the Windows host it lives on. The work has three parts: install and configure `openssh-server` in the distro, make sure `sshd` starts reliably, and, if you're on WSL2, forward a Windows port into the WSL VM because WSL2 sits behind NAT.

## Know your WSL version first

* **WSL 1** shares the Windows network stack. Anything you run in WSL1 is reachable on the Windows host's IP directly.
* **WSL 2** runs in a lightweight VM with its own virtual NIC (usually `172.x.x.x`). Windows can reach it via localhost, but other devices on the network cannot unless you add a port forward.

Check which one you're on:

```powershell
wsl -l -v
```

## Step 1: Install OpenSSH in WSL

```bash
sudo apt update
sudo apt install openssh-server openssh-client
```

`openssh-client` lets you SSH out from WSL; `openssh-server` lets you SSH into it. Verify both landed:

```bash
ssh -V
sshd -T | head
```

## Step 2: Configure the SSH server

```bash
sudo nano /etc/ssh/sshd_config
```

Minimal changes worth making:

```sshconfig
# Listen on standard port, or change if you want
Port 22

# Listen on all interfaces (needed for WSL2 networking)
ListenAddress 0.0.0.0

# Disable root login
PermitRootLogin no

# Password auth optional: keep on for simplicity, off for keys-only
PasswordAuthentication yes
```

`ListenAddress 0.0.0.0` matters specifically for WSL2, since `sshd` needs to bind on all interfaces to be reachable through the port forward you'll set up in Step 6. If you change the port, remember to update the forwarding rule to match.

Restart `sshd` after editing:

```bash
sudo service ssh restart
# or if systemd is on:
sudo systemctl restart ssh
```

## Step 3: Start SSH automatically

### If your WSL distro supports systemd (common now)

Enable it in `/etc/wsl.conf`:

```ini
[boot]
systemd=true
```

Restart WSL from PowerShell:

```powershell
wsl --shutdown
```

Back in WSL:

```bash
sudo systemctl enable ssh
sudo systemctl start ssh
sudo systemctl status ssh
```

### If you don't have systemd

Start manually:

```bash
sudo service ssh start
sudo service ssh status
```

Or start it on shell launch by adding this to `~/.bashrc` or `~/.profile`:

```bash
sudo service ssh start >/dev/null 2>&1
```

## Step 4: Set up authentication

For password login, make sure your WSL user has one set:

```bash
passwd
```

For keys, which is the better option, generate and copy a key from the machine you connect *from*:

```bash
ssh-keygen -t ed25519
ssh-copy-id your_wsl_user@HOST_ALIAS_OR_IP
```

Once keys work, you can disable `PasswordAuthentication` in `sshd_config`.

## Step 5: Connect locally from Windows

WSL1 and WSL2 both work the same way here, since Windows forwards localhost into the WSL2 VM automatically:

```powershell
ssh your_wsl_user@localhost
```

If you changed the port:

```powershell
ssh -p 2222 your_wsl_user@localhost
```

## Step 6: Enable access from other computers (WSL2)

Because WSL2 is NATed, other devices on your LAN can't reach it directly. Windows needs to forward a port from itself into the WSL VM.

Get the WSL2 IP:

```bash
ip addr show eth0
```

You'll get something like `172.29.64.5`. In an elevated PowerShell:

```powershell
netsh interface portproxy add v4tov4 `
  listenport=2222 listenaddress=0.0.0.0 `
  connectport=22 connectaddress=172.29.64.5
```

This makes Windows listen on port 2222 and forward to WSL's port 22. Open the firewall for that port:

```powershell
New-NetFirewallRule -DisplayName "Allow SSH to WSL2" `
  -Direction Inbound -Protocol TCP -Action Allow -LocalPort 2222
```

From another machine on the LAN:

```bash
ssh -p 2222 your_wsl_user@<windows_host_ip>
```

## Step 7: Survive reboots

WSL2's internal IP changes after a reboot or sleep, which breaks the portproxy rule you just set up. Re-applying it is the fix. A small PowerShell script does the job:

```powershell
$wslIp = (wsl hostname -I).Trim()
netsh interface portproxy reset
netsh interface portproxy add v4tov4 listenport=2222 listenaddress=0.0.0.0 connectport=22 connectaddress=$wslIp
```

Run it after reboot, or hook it to Task Scheduler on "At log on".

## Troubleshooting

**Connection refused**: `sshd` isn't running.

```bash
sudo service ssh start
```

**Port forward exists but you still can't connect**: check the portproxy rules and confirm the firewall rule is present.

```powershell
netsh interface portproxy show all
```

**WSL2 IP changed**: re-run the forwarding script from Step 7.

**sshd won't start**: check the logs.

```bash
sudo journalctl -u ssh --no-pager
# or without systemd
sudo tail -n 200 /var/log/auth.log
```

## Security notes worth doing

* Use SSH keys and set `PasswordAuthentication no`.
* Keep `PermitRootLogin no`.
* Moving off port 22 doesn't add real security, but it cuts down the drive-by scan noise in your logs.

After this, you have a small Linux server living inside Windows: reachable from your desktop, your laptop, or anywhere else on the LAN, without depending on Windows' own remote access tooling.
