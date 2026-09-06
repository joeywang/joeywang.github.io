---
layout: post
title: "Docker Buildx --on-error: drop into a shell when a build fails"
description: "The --on-error flag in Docker Buildx drops you into a shell inside the failing build step so you can inspect state instead of guessing from logs."
date: 2024-10-22 00:00 +0000
categories: [DevOps]
tags: [docker, debugging, ci, devops]
---
<audio controls preload="metadata" src="/assets/audio/advanced-docker-buildx-debugging-guide-using-on-error-summary.ogg">
  Your browser does not support the audio element.
</audio>


A build fails on step 7 of 12, Buildx prints the error, and the container that failed is already gone. Guessing what the file system looked like at that moment by adding echo statements and rebuilding costs a full rebuild per guess. The `--on-error` flag skips the guessing: it drops you into a shell inside the failing container the moment the step fails.

## Basic usage

```Dockerfile
FROM ubuntu:22.04
RUN apt-get update
RUN apt-get install -y nonexistent-package
RUN echo "This won't run due to previous error"
```

```bash
docker buildx build --progress=plain --on-error=continue .
```

When the install step fails, you land in a shell instead of a stack trace:

```bash
#18 [3/4] RUN apt-get install -y nonexistent-package
#18 ERROR: process "apt-get install -y nonexistent-package" did not complete successfully: exit code: 100

>>> Entering debug shell ...
root@f8d9a2b3c4:/#
```

From there, the usual tools work as expected: `apt-cache search`, `cat /var/log/apt/term.log`, `env`, or just retrying the failing command by hand with different arguments.

## Multi-stage and cached builds

`--on-error` composes with the flags you'd already use to reproduce a build. Target a specific stage to debug it in isolation:

```bash
docker buildx build \
  --progress=plain \
  --on-error=continue \
  --target builder .
```

Or keep the build cache so retries stay fast while you iterate on the fix:

```bash
docker buildx build \
  --progress=plain \
  --on-error=continue \
  --cache-from type=local,src=/tmp/cache \
  --cache-to type=local,dest=/tmp/cache .
```

## What to check once you're in

Most failures fall into three buckets, and the shell answers them directly:

- Network: `curl -v https://registry.npmjs.org`, `ping -c 3 google.com`
- File system: `ls -la`, `df -h`, `find / -name "missing-file"`
- Permissions: `id`, `namei -l /path/to/file`

Exit the shell and clean up the leftover build containers when you're done:

```bash
docker buildx prune
```

## The catch

The debug container is a live, running container, not a hypothetical one. It stays up until you exit it, holding disk and memory the same way any other container does. And if you install debugging tools for convenience while you're in there, make sure they don't leak into the image you actually ship. `--on-error` is for the terminal, not for the Dockerfile.
