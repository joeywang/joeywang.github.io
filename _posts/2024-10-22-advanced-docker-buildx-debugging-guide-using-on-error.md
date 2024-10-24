---
layout: post
title: 'Advanced Docker Buildx Debugging Guide: Using --on-error'
date: 2024-10-22 00:00 +0000
categories: [Docker, Buildx]
tags: [docker, buildx, on-error]
---
# Advanced Docker Buildx Debugging Guide: Using --on-error

## Introduction to Buildx --on-error

The `--on-error` flag in Docker Buildx is a powerful debugging feature that allows you to inspect the build container's state when a build step fails. This is particularly useful for:
- Investigating build failures in complex Dockerfiles
- Debugging package installation issues
- Troubleshooting configuration problems
- Examining file system state at the point of failure

## Basic Usage

### 1. Simple Example with --on-error

```Dockerfile
FROM ubuntu:22.04
RUN apt-get update
RUN apt-get install -y nonexistent-package
RUN echo "This won't run due to previous error"
```

Debug command:
```bash
docker buildx build --progress=plain --on-error=continue .
```

When the build fails, you'll get a shell in the container:
```bash
#18 [3/4] RUN apt-get install -y nonexistent-package
#18 ERROR: process "apt-get install -y nonexistent-package" did not complete successfully: exit code: 100

>>> Entering debug shell ...
root@f8d9a2b3c4:/#
```

### 2. Interactive Debugging

Once in the debug shell, you can:
```bash
# Check package availability
root@f8d9a2b3c4:/# apt-cache search your-package

# View logs
root@f8d9a2b3c4:/# cat /var/log/apt/term.log

# Test commands manually
root@f8d9a2b3c4:/# apt-get install -y your-package

# Check environment variables
root@f8d9a2b3c4:/# env
```

## Advanced Usage Examples

### 1. Debugging Complex Build Dependencies

```Dockerfile
FROM node:16
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build     # Assuming this fails
```

Debug command with additional options:
```bash
docker buildx build \
  --progress=plain \
  --on-error=continue \
  --no-cache \
  --build-arg NODE_ENV=development .
```

### 2. Debugging Multi-stage Builds

```Dockerfile
FROM golang:1.20 AS builder
WORKDIR /app
COPY go.* ./
RUN go mod download
COPY . .
RUN go build -v    # If this fails

FROM alpine:3.18
COPY --from=builder /app/myapp /usr/local/bin/
```

Debug command for specific stage:
```bash
docker buildx build \
  --progress=plain \
  --on-error=continue \
  --target builder .
```

### 3. Debugging with BuildKit Cache

```Dockerfile
FROM python:3.9
WORKDIR /app
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
COPY . .
RUN python setup.py build  # Debug this step
```

Debug command with cache options:
```bash
docker buildx build \
  --progress=plain \
  --on-error=continue \
  --cache-from type=local,src=/tmp/cache \
  --cache-to type=local,dest=/tmp/cache .
```

## Best Practices for --on-error Debugging

### 1. Using --progress Options

```bash
# Default progress output
docker buildx build --on-error=continue .

# Plain text output (most detailed)
docker buildx build --progress=plain --on-error=continue .

# Detailed output with timing
docker buildx build --progress=plain --on-error=continue --no-cache .
```

### 2. Combining with Other Debug Flags

```bash
# Maximum verbosity
docker buildx build \
  --progress=plain \
  --on-error=continue \
  --no-cache \
  --build-arg BUILDKIT_STEP_LOG_MAX_SIZE=-1 \
  --build-arg BUILDKIT_STEP_LOG_MAX_SPEED=-1 .
```

### 3. Debug Environment Setup

```Dockerfile
# Add debugging tools in your Dockerfile
RUN apt-get update && apt-get install -y \
    vim \
    curl \
    netcat \
    strace \
    tcpdump

# Use these in your debug session
```

## Common Debugging Scenarios

### 1. Network Issues
```bash
# In debug shell
root@f8d9a2b3c4:/# ping -c 3 google.com
root@f8d9a2b3c4:/# curl -v https://registry.npmjs.org
root@f8d9a2b3c4:/# netstat -tulpn
```

### 2. File System Issues
```bash
# In debug shell
root@f8d9a2b3c4:/# ls -la
root@f8d9a2b3c4:/# df -h
root@f8d9a2b3c4:/# find / -name "missing-file"
```

### 3. Permission Issues
```bash
# In debug shell
root@f8d9a2b3c4:/# id
root@f8d9a2b3c4:/# ls -l /problem/directory
root@f8d9a2b3c4:/# namei -l /path/to/file
```

## Exiting and Cleanup

```bash
# Exit the debug shell
root@f8d9a2b3c4:/# exit

# Clean up afterward
docker buildx prune
```

## Tips and Tricks

1. **Preserve Debug Container**
```bash
# Start new build with preserved debug container
docker buildx build --progress=plain --on-error=continue --keep .
```

2. **Export Debug Container**
```bash
# In another terminal while in debug session
docker commit <container-id> debug-image
docker run -it debug-image sh
```

3. **Create Debug Snapshot**
```bash
# In debug shell
tar czf /tmp/debug-snapshot.tar.gz /var/log /etc
# In another terminal
docker cp <container-id>:/tmp/debug-snapshot.tar.gz .
```

## Limitations and Considerations

1. **Resource Usage**
   - Debug sessions keep containers running
   - Monitor disk space and memory usage
   - Clean up debug containers regularly

2. **Security**
   - Don't leave debug tools in production images
   - Be cautious with sensitive information in debug sessions
   - Remove debug artifacts before pushing images

3. **Performance**
   - Debug builds are slower due to additional logging
   - Cache invalidation might occur more frequently
   - Consider using --cache-from for faster rebuilds
