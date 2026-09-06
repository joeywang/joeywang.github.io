---
layout: post
title: "Speeding Up Docker: Fixing Slow Host-to-Container File Sync"
date: 2025-05-29
tags: [docker, performance, macos]
categories: [DevOps]
description: "Bind-mounted host directories make Docker Desktop file access painfully slow on macOS and Windows, and this covers volumes, docker-sync, Mutagen, and WSL 2 fixes."
---

<audio controls preload="metadata" src="/assets/audio/docker-sync-summary.ogg">
  Your browser does not support the audio element.
</audio>

Docker makes it easy to develop in isolated environments, but file syncing between host and container can be painfully slow, especially on macOS and Windows. This gets serious fast on large projects like Node.js apps, where frequent file access to `node_modules` and rebuilds can wreck performance. Here's why syncing gets slow, and what actually fixes it: splitting volumes from bind mounts, tools like docker-sync and Mutagen, and platform-specific options like WSL 2.

## Volume vs. Bind Mounts: What's the Difference?

Docker provides two main mechanisms to access files inside a container:

### 1. Bind Mounts

```yaml
volumes:
  - .:/app
```

This maps a directory from the host directly into the container. It's useful for live reloads during development, but the host filesystem gets hit on every access, and on macOS and Windows that goes through a hypervisor layer, which is slow. It's worst for directories like `node_modules`, which have many small files.

### 2. Docker Volumes

```yaml
volumes:
  - /app/node_modules
```

Docker volumes live inside the Docker engine and are not backed by the host filesystem. They're much faster and ideal for directories that don't need to sync with the host, like `node_modules`.

---

## Strategy: Split Bind Mounts and Volumes

A good pattern is:

```yaml
volumes:
  - .:/app            # Sync code
  - /app/node_modules # Isolate dependencies
```

This lets you edit code live, but keeps heavy folders in the container.

For even more performance:

* Use `.dockerignore` to skip syncing `node_modules`, `.cache`, `.next`, etc.
* Avoid installing dependencies in a bind-mounted directory

---

## Tool: `docker-sync` (macOS only)

[`docker-sync`](http://docker-sync.io/) is built to speed up Docker on macOS by decoupling host-container sync using rsync, unison, or a native OS sync tool. It runs a background sync service, keeps that sync isolated from bind mount slowness, and syncs files into a Docker volume.

### Typical Setup

**`docker-sync.yml`**

```yaml
version: "2"
options:
  verbose: true
syncs:
  myapp-sync:
    src: './'
    sync_strategy: 'native_osx'
    sync_excludes: ['node_modules', '.git']
```

**`docker-compose.yml`**

```yaml
volumes:
  - myapp-sync:/app:nocopy
  - /app/node_modules
```

Then run:

```bash
docker-sync start
docker-compose up
```

Note: use `docker-sync` only on macOS. It's not useful or needed on Linux.

---

## Alternative Tools and Tactics

### Mutagen (cross-platform, fast sync)

A commercial-grade alternative to `docker-sync`, used by tools like Lando, Colima, and Tilt, and integrates directly with Docker Desktop via extensions. See [mutagen.io](https://mutagen.io/).

### Build Inside the Container

Rather than relying on bind mounts, do everything inside the container:

```Dockerfile
COPY . .
RUN npm ci
```

**Pros:**

* No sync at all
* Great for CI or staging

**Cons:**

* Need rebuilds for every code change
* Not ideal for active development

---

### Use WSL 2 (Windows only)

If you're on Windows, WSL 2 can drastically improve file I/O speeds compared to Docker Desktop's default setup. Mount your project from inside the Linux filesystem (`/home/user/project`) instead of from `C:\`.

### Use Dev Containers or Nix/Nixpacks

Environments like GitHub Codespaces or [Devbox](https://www.jetpack.io/devbox) provide isolated, reproducible setups that avoid local syncing entirely.

## Approximate Benchmarks

| Setup | Cold Start (s) | File Access Speed |
| --- | --- | --- |
| Bind mount w/ node_modules | 10-20+ | Very slow |
| Docker volume only | 2-5 | Fast |
| docker-sync (macOS) | 3-7 | Fast |
| Build-in-container (no sync) | 1-3 | Very fast |

## Recommendations by Use Case

| Use Case | Best Strategy |
| --- | --- |
| Live dev, file reload | Bind-mount code only, volume for deps |
| macOS dev | Add `docker-sync` |
| CI or staging | Build in container, no mount |
| Windows | Use WSL 2 and run inside Linux FS |
| Large monorepo | Selective mount, only essential folders |

## Template: `docker-compose.yml`

```yaml
services:
  app:
    build: .
    volumes:
      - .:/app
      - /app/node_modules
    ports:
      - "3000:3000"
```

Bind mounts offer convenience but cost performance. Splitting volumes from bind mounts, excluding heavy directories, or using a tool like `docker-sync` restores a fast developer experience on both Mac and Windows.
