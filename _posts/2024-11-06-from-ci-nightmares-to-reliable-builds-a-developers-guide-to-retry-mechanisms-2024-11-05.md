---
layout: post
title: "Retry mechanisms for flaky CI and Docker builds"
description: "Wrapping curl, bundle install, and Docker builds in retry logic turns transient network failures in CI into automatic retries instead of full pipeline restarts."
date: 2024-11-06 00:26 +0000
categories: [DevOps]
tags: [ci, docker, github-actions, devops]
---
<audio controls preload="metadata" src="/assets/audio/from-ci-nightmares-to-reliable-builds-a-developers-guide-to-retry-mechanisms-2024-11-05-summary.ogg">
  Your browser does not support the audio element.
</audio>


A flaky network connection can take out an entire CI build near the finish line: `curl` times out while pulling a package, and the whole pipeline restarts from scratch. The fix isn't a faster network, it's retrying the specific step that's flaky, at every layer where it can fail.

## Docker build steps

A single `curl` in a Dockerfile fails the whole build on one bad connection:

```dockerfile
FROM node:16-alpine
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
```

Wrap it in a retry loop instead:

```dockerfile
FROM node:16-alpine
RUN for i in 1 2 3 4 5; do \
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash && break \
      || { echo "Retry attempt $i failed"; sleep 10; } \
    done

RUN apt-get update \
    && for i in 1 2 3 4 5; do \
         apt-get install -y --no-install-recommends some-package && break \
         || { echo "Retry attempt $i failed"; sleep 10; } \
       done
```

## Package managers

Bundler has retry support built in, and it's worth combining with a clean-and-retry fallback for cases where a partial install left `vendor/bundle` in a bad state:

```bash
bundle install --retry 3 --jobs 4 \
  || (echo "Bundle install failed, cleaning and retrying..." \
      && rm -rf vendor/bundle \
      && bundle install --retry 3 --jobs 4)
```

## CI pipeline steps

`nick-invision/retry` wraps an arbitrary shell command in GitHub Actions with retry and timeout semantics, which is useful for the install and build steps specifically rather than the whole job:

```yaml
name: Resilient CI Pipeline

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Cache dependencies
        uses: actions/cache@v2
        with:
          path: |
            ~/.npm
            ~/.bundle
          key: {% raw %}${{ runner.os }}-deps-${{ hashFiles('**/package-lock.json', '**/Gemfile.lock') }}{% endraw %}

      - name: Install dependencies with retry
        uses: nick-invision/retry@v2
        with:
          timeout_minutes: 10
          max_attempts: 3
          retry_wait_seconds: 30
          command: |
            npm ci
            bundle install --retry 3 --jobs 4

      - name: Build Docker image with retry
        uses: nick-invision/retry@v2
        with:
          timeout_minutes: 15
          max_attempts: 3
          command: |
            docker build \
              --network-retry-count 3 \
              --network-retry-interval 30 \
              -t myapp:{% raw %}${{ github.sha }}{% endraw %} .
```

## A generic retry function

When you need retry logic somewhere the CI vendor's action doesn't reach, a small shell function covers it:

```bash
#!/bin/bash
set -eo pipefail

retry() {
    local max_attempts="$1"
    local delay="$2"
    local command="${@:3}"
    local attempt=1

    until $command; do
        if (( attempt == max_attempts )); then
            echo "Command failed after $max_attempts attempts"
            return 1
        fi
        echo "Attempt $attempt failed! Retrying in ${delay}s..."
        sleep $delay
        ((attempt++))
    done
}

retry 3 10 bundle install --retry 3 --jobs 4
retry 3 30 docker build --network-retry-count 3 .
retry 3 10 npm ci
```

## Testing that the retry logic actually retries

It's easy to write a retry wrapper that looks right and never gets exercised until it matters. Force the failure path in a test:

```ruby
RSpec.describe "Build Resilience" do
  it "handles network failures gracefully" do
    allow(Docker).to receive(:build).and_raise(
      Excon::Error::Socket
    ).exactly(2).times.ordered
    allow(Docker).to receive(:build).and_return(true)

    expect { BuildProcess.new.run }.not_to raise_error
  end
end
```

## The limit

Retries fix transient failures. They also make a real, reproducible failure slower to notice, since it now fails after three attempts and a minute of sleeping instead of failing immediately. Track how often retries actually fire, a counter per stage is enough, so a step that's failing consistently, not occasionally, gets fixed instead of quietly retried forever.
