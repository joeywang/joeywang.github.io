---
layout: post
title:  "Incus vs. Docker: The Next-Generation Guide to System Containers"
date:   2026-04-06 10:00:00 -0400
categories: incus docker
---

## Incus vs. Docker: The Next-Generation Guide to System Containers

In the world of containerization, **Docker** has long been the household name. However, for developers who need more than just a place to run a single process, **Incus** has emerged as the premier community-driven alternative. 

While Docker focuses on **Application Containers** (packaging a single app), Incus focuses on **System Containers** (packaging a full Linux OS). Think of Incus as a way to create "instant Virtual Machines" that run at the speed of a container.

---

### 🚀 Key Differences at a Glance

| Feature | Docker | Incus |
| :--- | :--- | :--- |
| **Philosophy** | "One process per container" | "One full OS per container" |
| **Primary Use** | Microservices, CI/CD, Deployment | Development Labs, AI Sandboxing, VPS replacement |
| **Init System** | No (Usually just `entrypoint`) | Yes (`systemd`, `OpenRC` work natively) |
| **Security** | Process-level isolation | Unprivileged containers by default + VM support |
| **Persistence** | Volatile (requires Volumes/Bind mounts) | Persistent (acts like a physical disk) |
| **Hardware** | Hard to pass through GPUs/USB | Native, low-latency device passthrough |



---

### ⌨️ Command Comparison: Speaking the Language
If you already know Docker, learning Incus is a matter of mapping your existing knowledge to a new set of verbs.

| Action | Docker Command | Incus Command |
| :--- | :--- | :--- |
| **Start a container** | `docker run -d --name web ubuntu` | `incus launch images:ubuntu/24.04 web` |
| **List containers** | `docker ps` | `incus list` |
| **Access shell** | `docker exec -it web bash` | `incus shell web` |
| **Stop container** | `docker stop web` | `incus stop web` |
| **Remove container** | `docker rm -f web` | `incus delete -f web` |
| **Create Image** | `docker commit web my-image` | `incus publish web --alias my-image` |
| **View Logs** | `docker logs web` | `incus info --show-log web` |
| **Copy Files** | `docker cp file web:/path` | `incus file push file web/path` |

---

### 🛠️ Setting Up Your Incus Environment (Ubuntu 24.04+)

Incus is now officially supported in the latest Ubuntu repositories, making installation a breeze.

#### 1. Installation & Init
```bash
# Install the core packages
sudo apt update && sudo apt install -y incus

# Add your user to the management group
sudo usermod -aG incus-admin $USER
newgrp incus-admin

# Initialize the system (Interactive Wizard)
incus admin init
```
*Tip: During `init`, choosing **ZFS** or **Btrfs** for storage allows for near-instant snapshots.*

#### 2. Launching your first "Dev Box"
Unlike Docker Hub, Incus uses multiple "remotes." The most common is the community-maintained `images:` server.
```bash
# Launch a persistent Ubuntu 24.04 container
incus launch images:ubuntu/24.04 dev-box

# Launch a MicroVM (for AI sandboxing or extra security)
incus launch images:ubuntu/24.04 ai-box --vm
```

---

### 🤖 Advanced Management: The "Pro" Workflow

#### Using Profiles for Automation
Instead of manual configuration, you can use **Profiles** to apply settings (like GPU access or mounted folders) to many containers at once.

```bash
# Create a profile for Rails development
incus profile create rails-dev

# Add a device to map your code folder from the host
incus profile device add rails-dev my-code disk \
    source=/home/user/projects/app \
    path=/root/app

# Apply this profile to your container
incus profile add dev-box rails-dev
```

#### Snapshotting (The "Undo" Button)
This is where Incus shines over Docker for development. Before making a big change:
```bash
# Create a snapshot
incus snapshot create dev-box pre-upgrade

# Messed up? Restore instantly
incus restore dev-box pre-upgrade
```

#### Running Docker inside Incus
Yes, you can have the best of both worlds. To run Docker inside an Incus container (nesting):
```bash
incus config set dev-box security.nesting=true
incus restart dev-box
# Now install docker inside the dev-box as usual!
```

---

### 🎯 Conclusion
**Use Docker** when you have a finished app that you want to ship to the cloud.
**Use Incus** when you are *building* that app. It provides a stable, persistent, and high-performance environment that handles system services and hardware with ease—all while keeping your host machine clean and organized.
