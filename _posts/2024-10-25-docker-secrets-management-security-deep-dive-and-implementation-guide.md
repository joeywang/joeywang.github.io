---
layout: post
title: "Docker secrets: how layers leak them and how BuildKit fixes it"
description: "Docker's layer history persists secrets baked into ARG and ENV instructions, and BuildKit secret mounts are the practical fix that keeps them out of the image."
date: 2024-10-25 00:00 +0000
categories: [DevOps, Security]
tags: [docker, security, devops]
---
<audio controls preload="metadata" src="/assets/audio/docker-secrets-management-security-deep-dive-and-implementation-guide-summary.ogg">
  Your browser does not support the audio element.
</audio>


Every `RUN`, `ARG`, and `ENV` instruction in a Dockerfile creates a layer, and Docker's layer history is immutable and additive. That has a specific consequence for secrets: a pattern like

```dockerfile
ARG DB_PASSWORD
ENV DATABASE_URL="postgresql://user:${DB_PASSWORD}@localhost/db"
```

puts the password straight into the image, and `docker history` proves it:

```bash
IMAGE          CREATED       CREATED BY                                      SIZE
abc123         2 minutes ago |1 DATABASE_URL=postgresql://user:secretp...   1.07kB
```

Deleting the secret in a later layer doesn't help. The earlier layer with the plaintext value is still part of the image and still pullable by anyone with access to it. The value lives in image metadata, layer history, the build cache, and build logs, all at once.

## BuildKit secret mounts

BuildKit's `--mount=type=secret` gives a build step access to a secret without writing it to any layer:

```dockerfile
FROM alpine
RUN --mount=type=secret,id=github_token,target=/root/.github_token \
    gh auth login --with-token < /root/.github_token && \
    gh repo clone private/repo
```

```bash
DOCKER_BUILDKIT=1 docker build \
  --secret id=github_token,src=${GITHUB_TOKEN_FILE} \
  --no-cache \
  -t secure-image .
```

The secret is mounted into a memory-backed tmpfs for the duration of that one `RUN` step and never touches the layer that step produces.

## Multi-stage builds as a second boundary

Secret mounts handle build-time exposure; multi-stage builds handle the runtime image. A build stage can hold secrets it needs to fetch dependencies, and the final stage copies out only the built artifact:

```dockerfile
FROM node:16 AS builder
RUN --mount=type=secret,id=npm_token \
    echo "//registry.npmjs.org/:_authToken=$(cat /run/secrets/npm_token)" > .npmrc && \
    npm install && rm .npmrc

FROM node:16-slim
COPY --from=builder /app/dist /app
# no access to builder's secrets or its layer history
```

## Runtime secrets

Build-time secrets and runtime secrets are different problems. At runtime, let the orchestrator manage them instead of baking them into the image:

```yaml
# Docker Swarm
services:
  app:
    image: myapp
    secrets:
      - db_password
    environment:
      - DB_URL=/run/secrets/db_password

secrets:
  db_password:
    external: true
```

Kubernetes secrets and mounted env files follow the same principle: the value is injected at container start, not baked into the image.

## Checking your work

Don't take the mount type's word for it. Scan the actual layers:

```bash
docker save myimage:latest | tar -xO | grep -i -E 'password|secret|token|key'
trivy image myimage:latest
```

If either turns up a hit, the fix is almost always the same: move the offending instruction from `ARG`/`ENV` to a BuildKit secret mount, and rebuild with `--no-cache` so the old layer isn't still sitting in the cache.
