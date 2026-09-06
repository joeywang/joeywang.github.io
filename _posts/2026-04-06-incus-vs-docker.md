---
layout: post
title:  "Incus vs. Docker: System Containers vs. App Containers"
description: "A practical comparison of Incus and Docker: when system containers suit development environments better than single-process application containers."
date:   2026-04-06 10:00:00 -0400
categories: [DevOps]
tags: [docker, incus, linux, devops]
---
<audio controls preload="metadata" src="/assets/audio/incus-vs-docker-summary.ogg">
  Your browser does not support the audio element.
</audio>

Docker is the household name in containerization, but it was built around one idea: package a single process. Incus takes a different approach: it packages a full Linux OS as a container, giving you something like an instant VM that runs at container speed. Once you need more than "run this one process," that difference starts to matter.

## Key differences at a glance

| Feature | Docker | Incus |
| :--- | :--- | :--- |
| Philosophy | One process per container | One full OS per container |
| Primary use | Microservices, CI/CD, deployment | Development labs, AI sandboxing, VPS replacement |
| Init system | No (usually just an entrypoint) | Yes (systemd, OpenRC work natively) |
| Security | Process-level isolation | Unprivileged containers by default, plus VM support |
| Persistence | Volatile (needs volumes or bind mounts) | Persistent, acts like a physical disk |
| Hardware | Hard to pass through GPUs or USB | Native, low-latency device passthrough |

## Command comparison

If you already know Docker, learning Incus is mostly a matter of mapping familiar verbs to new ones.

| Action | Docker command | Incus command |
| :--- | :--- | :--- |
| Start a container | `docker run -d --name web ubuntu` | `incus launch images:ubuntu/24.04 web` |
| List containers | `docker ps` | `incus list` |
| Access shell | `docker exec -it web bash` | `incus shell web` |
| Stop container | `docker stop web` | `incus stop web` |
| Remove container | `docker rm -f web` | `incus delete -f web` |
| Create image | `docker commit web my-image` | `incus publish web --alias my-image` |
| View logs | `docker logs web` | `incus info --show-log web` |
| Copy files | `docker cp file web:/path` | `incus file push file web/path` |

## Setting up Incus (Ubuntu 24.04+)

Incus is officially in the latest Ubuntu repositories, so getting it running is straightforward.

### Installation and init

```bash
# Install the core packages
sudo apt update && sudo apt install -y incus

# Add your user to the management group
sudo usermod -aG incus-admin $USER
newgrp incus-admin

# Initialize the system (interactive wizard)
incus admin init
```

During `init`, choosing ZFS or Btrfs for storage gets you near-instant snapshots later, which is worth the extra setup step.

### Launching your first dev box

Unlike Docker Hub, Incus talks to multiple "remotes." The most common is the community-maintained `images:` server.

```bash
# Launch a persistent Ubuntu 24.04 container
incus launch images:ubuntu/24.04 dev-box

# Launch a MicroVM (for AI sandboxing or extra isolation)
incus launch images:ubuntu/24.04 ai-box --vm
```

## Managing more than one container

### Profiles for repeatable configuration

Instead of configuring each container by hand, profiles apply a set of settings, GPU access or mounted folders, for example, to many containers at once.

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

### Snapshots as an undo button

This is where Incus is genuinely better than Docker for development work. Before a risky change:

```bash
# Create a snapshot
incus snapshot create dev-box pre-upgrade

# Messed up? Restore instantly
incus restore dev-box pre-upgrade
```

### Running Docker inside Incus

You can have both. To nest Docker inside an Incus container:

```bash
incus config set dev-box security.nesting=true
incus restart dev-box
# Now install docker inside the dev-box as usual
```

## Which one to reach for

Use Docker when you have a finished app you want to ship to the cloud. Use Incus when you're building that app: it gives you a stable, persistent, high-performance environment that handles system services and hardware directly, while keeping your host machine clean.
</content>
