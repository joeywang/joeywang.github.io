---
layout: post
title: "How to Debug Docker Image Builds"
description: "Practical techniques for debugging Docker image builds: BuildKit output flags, inspecting intermediate layers, nsenter tricks, and multi-stage build targets."
date: 2024-10-21 00:00 +0000
categories: [DevOps]
tags: [docker, debugging, devops, ci]
---

<audio controls preload="metadata" src="/assets/audio/how-to-debug-docker-image-builds-summary.ogg">
  Your browser does not support the audio element.
</audio>


A Docker build that fails on step 14 of 20 hands you an error message and not much else. The container that ran the failing command is gone, and the obvious move, adding echo statements and rebuilding, costs minutes per attempt. These are the techniques I reach for instead.

## Get more output from BuildKit

BuildKit, the default builder in modern Docker, truncates step logs by default. Turn that off first:

```bash
# Enable detailed debugging output
BUILDKIT_STEP_LOG_MAX_SIZE=-1 docker build .

# Continue build after error (buildx feature)
docker buildx build --progress=plain --on-error=continue .

# Print verbose output
docker buildx build --progress=plain .
```

`--progress=plain` alone solves a surprising number of "why did this fail" questions. The interactive progress UI hides the exact output you need.

## Debug a failed layer

### Remove the failing command and inspect the state before it

If you have a failing command like:

```Dockerfile
FROM busybox
RUN echo 'hello world' > /tmp/test
RUN exit 1  # problematic command
RUN echo 'ready'
```

Remove the failing command and everything after it:

```Dockerfile
FROM busybox
RUN echo 'hello world' > /tmp/test
```

Build that, then run a shell in the result and try the failing command by hand.

### Inspect intermediate layers

The legacy builder prints the SHA of every intermediate layer, which BuildKit hides. Turn BuildKit off when you want to shell into the last good layer:

```bash
DOCKER_BUILDKIT=0 docker build -t test .
# Use the SHA of the last successful layer
docker run --rm -it <sha> sh
```

## Interactive debugging with nsenter

Sometimes you want a shell inside the build container while the build is running. Park the build on a `sleep` and enter its namespace:

```Dockerfile
FROM busybox
RUN echo 'hello world'
RUN sleep infinite  # Add this for debugging
RUN exit 1
```

```bash
# In terminal 1: Start the build
docker build -t test .

# In terminal 2: Enter the container's namespace
docker run -it --rm --privileged --pid=host justincormack/nsenter1
ps -ef | grep sleep
nsenter -p -m -u -i -n -t <PID> sh
```

An alternative using a plain Alpine image:

```bash
docker run --privileged --pid=host -it alpine \
nsenter -t 1 -m -u -n -i sh
```

This is a blunt instrument, it needs `--privileged`, but it works when nothing else does.

## Multi-stage builds as debug checkpoints

Named stages give you build targets you can stop at:

```Dockerfile
FROM busybox as working
RUN echo 'hello world'

FROM working as error
RUN exit 1
```

```bash
# Build specific target
docker build -t test --target working .
# Debug the working stage
docker run --rm -it test sh
```

The same idea keeps debugging tools out of production images. Install them in a development stage only:

```Dockerfile
# Development stage with debugging tools
FROM ruby:3.2 as development
RUN apt-get update && \
    apt-get install -y vim curl htop

# Production stage
FROM ruby:3.2-slim as production
COPY --from=development /app /app
```

## BuildKit mounts

Two BuildKit features change how you debug slow or secret-dependent builds. Cache mounts stop package downloads from being the slowest part of every retry loop:

```Dockerfile
# Cache apt packages
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && apt-get install -y build-essential
```

Secret mounts keep credentials out of layers while you test steps that need them:

```Dockerfile
# Mount secrets during build
RUN --mount=type=secret,id=mysecret cat /run/secrets/mysecret
```

## A Rails Dockerfile with debugging in mind

The same principles applied to a Rails image: cache mounts for apt, debug gems gated behind a build arg, dependency files copied before the app so the expensive layers cache well.

```Dockerfile
FROM ruby:3.2

# Install essential libraries
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && \
    apt-get install -y \
    libssl-dev \
    postgresql-client \
    nodejs \
    npm

# Set working directory
WORKDIR /app

# Install debugging tools in development
ARG RAILS_ENV=development
RUN if [ "$RAILS_ENV" = "development" ]; then \
    gem install debase ruby-debug-ide; \
    fi

# Copy Gemfile and install dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Install JavaScript dependencies
COPY package.json yarn.lock ./
RUN npm install -g yarn && yarn install

# Copy application code
COPY . .

# Start Rails server
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```

## Quick checks worth remembering

Common failure classes and the one-liner that diagnoses them:

```bash
# Debug bundle install
docker run --rm -it <image-id> bundle install --verbose

# Test network connectivity from inside the image
docker run --rm -it <image-id> ping -c 3 google.com

# Analyze image layers with dive
dive <image-name>

# View layer history
docker history --no-trunc <image-name>
```

Permission problems are usually fixed in the Dockerfile itself:

```Dockerfile
RUN chown -R user:user /app
USER user
```

## The principle

Fast debugging of Docker builds comes down to shortening the loop: get full output, stop at the last good layer, and get a shell as close to the failure as possible. And clean up after yourself. Debug layers, sleep hacks, and privileged helpers belong in your terminal history, not in the image you push.
