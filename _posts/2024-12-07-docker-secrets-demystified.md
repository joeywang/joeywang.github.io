---
layout: post
title: "ARG, ENV, and BuildKit secrets: how each behaves in Docker"
description: "ARG, ENV, exported shell variables, and BuildKit secret mounts each persist differently in a Docker image, and only one of them is actually safe for tokens."
date: 2024-12-07 00:00 +0000
categories: [DevOps, Security]
tags: [docker, security, devops]
---
<audio controls preload="metadata" src="/assets/audio/docker-secrets-demystified-summary.ogg">
  Your browser does not support the audio element.
</audio>


The same Dockerfile can declare a value four different ways, `ARG`, `ENV`, an exported shell variable, or a BuildKit secret mount, and each one persists differently. Only one of them is actually safe to put a token in.

```dockerfile
FROM alpine
ARG arg_key
ENV env_key=45678
RUN export EXPORT_KEY=123455 ls
RUN INLINE_KEY=123456 ls
RUN echo $arg_key
RUN --mount=type=secret,id=github_key,required=true \
    export GITHUB_KEY="$(cat /run/secrets/github_key)" && echo 'this is safe'
```

## What each one actually does

**`ARG`** exists only at build time. It's accessible while the image is being built, and gone from the runtime environment, but it still shows up in `docker history` and the build cache, so it's not safe for anything sensitive.

**`ENV`** persists into the final image and stays there for the container's whole lifecycle. Anyone who can run the image, or pull its layers, can read it. Fine for configuration, wrong for secrets.

**`export EXPORT_KEY=... ls`** and **`INLINE_KEY=... ls`** are both scoped to that one `RUN` command. Neither survives into the next layer. Useful for one-off shell logic, not a substitute for real secret handling.

**BuildKit's `--mount=type=secret`** is the one built for this. The value is mounted into the step at build time and never written to a layer:

```dockerfile
RUN --mount=type=secret,id=github_key,required=true \
    export GITHUB_KEY="$(cat /run/secrets/github_key)" && echo 'this is safe'
```

`required=true` fails the build outright if the secret isn't provided, which is better than a build that silently proceeds with an empty token.

| Type | Persistence | Safe for secrets |
|------|-------------|-------------------|
| `ARG` | Build-time only, but visible in history | No |
| `ENV` | Full container runtime | No |
| exported / inline var | Single `RUN` command | No, but fine for non-sensitive one-off logic |
| BuildKit secret mount | Temporary, never in a layer | Yes |

## Where this shows up in practice

Cloning a private repository during a build is the case that comes up most:

```dockerfile
RUN --mount=type=secret,id=github_token \
    git clone https://token:$(cat /run/secrets/github_token)@github.com/org/repo.git
```

Baking the token into an `ARG` or `ENV` instead would leave it sitting in the image's layer history indefinitely, readable by anyone who can pull the image or inspect its layers, long after the token itself has been rotated.
