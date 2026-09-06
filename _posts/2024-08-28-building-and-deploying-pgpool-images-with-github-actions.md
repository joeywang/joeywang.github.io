---
layout: post
title: "Building and Deploying pgpool Images with GitHub Actions"
description: "A GitHub Actions workflow that builds multi-architecture pgpool images for several versions in parallel and pushes them to GitHub Container Registry."
date: 2024-08-28 00:00 +0000
categories: [DevOps]
tags: [github-actions, docker, ci, postgresql]
---

<audio controls preload="metadata" src="/assets/audio/building-and-deploying-pgpool-images-with-github-actions-summary.ogg">
  Your browser does not support the audio element.
</audio>

pgpool is a connection pooler and load balancer for PostgreSQL, and keeping a custom image for it up to date across versions is exactly the kind of repetitive job worth automating. Here's a GitHub Actions workflow that builds pgpool images for multiple versions and pushes them to GitHub Container Registry.

A matrix strategy is what makes this worth automating rather than scripting by hand: one job definition runs once per version, in parallel, instead of a hand-rolled loop or a copy-pasted job per version.

## Setting up the workflow

Below is a breakdown of the YAML configuration.

### Workflow Trigger

The workflow is triggered on every push to the repository:

```yml
on:
  push:
```

### Permissions

We specify the necessary permissions for the workflow to interact with the repository and package registry:

```yml
permissions:
  contents: write
  packages: write
```

### Environment Variables

The Docker repository path is set as an environment variable:

```yml
env:
  DOCKER_REPO: ghcr.io/${{ github.repository_owner }}/pgpool
```

### Jobs

The job is defined with a name and runs on the latest Ubuntu runner with a timeout set to 20 minutes:

```yml
jobs:
  publish_docker:
    runs-on: ubuntu-latest
    timeout-minutes: 20
```

### Strategy

Using the matrix strategy, we can build images for multiple PGPool versions:

```yml
strategy:
  fail-fast: false
  matrix:
    version: ['4.4.8', '4.5.3']
```

### Steps

The steps include checking out the repository, setting up QEMU, Buildx, logging into the GitHub Container Registry, and finally building and pushing the images:

```yml
steps:
  - uses: actions/checkout@v4
  - uses: docker/setup-qemu-action@v3
  - uses: docker/setup-buildx-action@v3

  - name: Login to Github Container Registry
    uses: docker/login-action@v3
    with:
      registry: ghcr.io
      username: ${{ github.actor }}
      password: ${{ secrets.GITHUB_TOKEN }}

  - name: Build and push images
    uses: docker/build-push-action@v6
    with:
      context: ./pgpool.docker/
      file: ./pgpool.docker/Dockerfile.pgpool
      build-args: |
        PGPOOL_VER=${{ matrix.version }}
      push: true
      platforms: linux/amd64,linux/arm64
      tags: |
        ${{ env.DOCKER_REPO }}:${{ matrix.version }}
```

### Key Components

- **checkout**: Checks out the repository to the runner.
- **setup-qemu-action**: Installs QEMU to enable building multi-platform images.
- **setup-buildx-action**: Sets up Docker Buildx for building and pushing images.
- **login-action**: Logs into the GitHub Container Registry using the GITHUB_TOKEN.
- **build-push-action**: Builds the Docker image for the specified platform and pushes it to the registry.

## The result

This workflow keeps pgpool images current without a manual build step: add a version to the matrix, and the next push builds and pushes it. The same shape, checkout, buildx, login, matrix build, works for any other database tool image you need to maintain the same way.

