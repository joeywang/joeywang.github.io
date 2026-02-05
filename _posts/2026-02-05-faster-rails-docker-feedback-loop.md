---
layout: post
title: "Faster Rails Docker Feedback Loop: Runtime Bundler, Yarn Cache, and HMR"
date: 2026-02-05
tags: [rails, docker, docker-compose, webpacker, hmr, bundler, yarn, productivity]
categories: [Development, DevOps]
description: "How I reduced Docker development friction across three Rails apps by removing rebuild-heavy steps, adding runtime dependency sync, and enabling webpack HMR."
---

# Faster Rails Docker Feedback Loop: Runtime Bundler, Yarn Cache, and HMR

When local development runs in Docker, feedback loop speed often gets worse over time.

I hit the same 3 problems repeatedly in `wfb`, `n2r`, and `turtle`:

1. `bundle update` forced image rebuilds to apply Gem changes.
2. `yarn install` repeated expensive work.
3. asset precompile-related startup paths slowed each iteration.

This post documents the improvements I applied across all three projects, with exact patterns you can reuse.

---

## 1. What was slowing the loop

The main anti-pattern was build-time coupling:

1. dependencies were treated like immutable build artifacts
2. day-to-day dependency changes were frequent in development
3. webpack dev flow was not isolated for true hot updates

That combination means a small `Gemfile.lock` or `yarn.lock` edit could trigger a full rebuild and stall development.

---

## 2. Design goals

I optimized for these goals:

1. no image rebuild needed for normal `Gemfile.lock` or `yarn.lock` changes
2. dependency installs are incremental and cached
3. web process and webpack dev server are split for HMR
4. worker/scheduler do not waste time on JS dependency checks
5. startup ordering is deterministic with healthchecks

---

## 3. Core implementation

### 3.1 Move install logic from Docker build to container entrypoint

Instead of baking `bundle install` and `yarn install` into `Dockerfile`, keep `Dockerfile` focused on runtime/toolchain setup and run dependency checks at startup.

Example (`Dockerfile` pattern):

```dockerfile
FROM ruby:4.0.1-slim

ENV NODE_MAJOR=${NODE_MAJOR:-24}
ARG YARN_VERSION=1.22.22

RUN apt-get update -qq \
  && apt-get install -y ca-certificates curl gnupg \
  && mkdir -p /etc/apt/keyrings \
  && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
      | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
  && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" \
      | tee /etc/apt/sources.list.d/nodesource.list

RUN apt-get update -qq \
  && DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
    build-essential libpq-dev nodejs postgresql-client python3 git libyaml-dev \
  && npm install -g yarn@${YARN_VERSION}

ARG app=/opt/wfb
WORKDIR $app

RUN adduser --disabled-login app \
  && mkdir -p $app $app/node_modules /usr/local/bundle /usr/local/share/.cache/yarn \
  && chown -R app:app $app /usr/local/bundle /usr/local/share/.cache/yarn \
  && gem install bundler --no-document

ENV BUNDLE_PATH=/usr/local/bundle \
    YARN_CACHE_FOLDER=/usr/local/share/.cache/yarn \
    RAILS_ENV=${RAILS_ENV:-development} \
    NODE_ENV=${NODE_ENV:-development}

COPY bin/docker-entrypoint /usr/local/bin/docker-entrypoint
RUN chmod +x /usr/local/bin/docker-entrypoint

COPY --chown=app:app . ./

USER app
ENTRYPOINT ["docker-entrypoint"]
CMD ["bundle", "exec", "puma", "-b", "tcp://0.0.0.0:8080"]
```

### 3.2 Runtime dependency sync with lock and change detection

I added `bin/docker-entrypoint` in each project to:

1. run `bundle check || bundle install`
2. run `yarn install` only when needed
3. avoid races using lock directories

Example entrypoint:

```sh
#!/bin/sh
set -e

with_lock() {
  lock_name="$1"
  shift
  lock_dir="/tmp/${lock_name}.lock"
  lock_timeout="${INSTALL_LOCK_TIMEOUT:-120}"
  waited=0

  while ! mkdir "$lock_dir" 2>/dev/null; do
    sleep 1
    waited=$((waited + 1))
    if [ "$waited" -ge "$lock_timeout" ]; then
      echo "Timed out waiting for lock: $lock_name" >&2
      return 1
    fi
  done

  trap 'rmdir "$lock_dir" 2>/dev/null || true' EXIT INT TERM
  "$@"
  status=$?
  rmdir "$lock_dir" 2>/dev/null || true
  trap - EXIT INT TERM
  return "$status"
}

ensure_bundle() {
  bundle config set path "${BUNDLE_PATH:-/usr/local/bundle}"
  bundle check || bundle install -j "${BUNDLE_JOBS:-4}" --retry "${BUNDLE_RETRY:-5}"
}

ensure_yarn() {
  yarn install --frozen-lockfile --check-files --prefer-offline --no-progress
}

if [ -f Gemfile ] && [ "${SKIP_BUNDLE_INSTALL:-0}" != "1" ] && [ "${AUTO_BUNDLE_INSTALL:-1}" = "1" ]; then
  with_lock app-bundle-install ensure_bundle
fi

if [ -f yarn.lock ] && [ "${SKIP_YARN_INSTALL:-0}" != "1" ] && [ "${AUTO_YARN_INSTALL:-1}" = "1" ]; then
  integrity_file="node_modules/.yarn-integrity"
  if [ ! -d node_modules ] || [ ! -f "$integrity_file" ] || [ yarn.lock -nt "$integrity_file" ] || [ package.json -nt "$integrity_file" ]; then
    with_lock app-yarn-install ensure_yarn
  fi
fi

exec "$@"
```

Notes:

1. In `turtle`, Yarn required `--ignore-engines` to match existing constraints.
2. In `turtle`, `BUNDLE_APP_CONFIG` was set to `$app/.bundle` to avoid permissions friction with mounted bundle paths.

### 3.3 Persist dependency state in named Docker volumes

Named volumes keep expensive installs across container restarts:

```yaml
x-app-service-template: &app
  build:
    context: .
    dockerfile: ${DOCKERFILE:-Dockerfile}
  volumes:
    - .:/opt/app
    - bundle:/usr/local/bundle
    - node_modules:/opt/app/node_modules
    - yarn_cache:/usr/local/share/.cache/yarn
```

This is the biggest practical win for day-to-day commands.

### 3.4 Separate webpack dev server for HMR

I added a dedicated `webpack` service:

```yaml
webpack:
  <<: *app
  command: bundle exec ./bin/webpack-dev-server
  ports:
    - "3035:3035"
  environment:
    - "RAILS_ENV=development"
    - "NODE_ENV=development"
    - "WEBPACKER_DEV_SERVER_POLL=1000"
```

And updated `webpacker.yml` development settings:

```yaml
development:
  compile: true
  dev_server:
    host: webpack
    port: 3035
    public: localhost:3035
    hmr: true
    inline: true
    watch_options:
      poll: <%= ENV.fetch('WEBPACKER_DEV_SERVER_POLL', 0) %>
      ignored: '**/node_modules/**'
```

Key detail: `host: webpack` maps Rails to the compose service name inside Docker networking.

### 3.5 Healthchecks and smarter dependency startup

I added healthchecks for DB/Redis and switched `depends_on` to `service_healthy`.

For non-web services (`worker`, `scheduler`) I set:

```yaml
environment:
  - "AUTO_YARN_INSTALL=0"
```

This avoids unnecessary JS install checks where they are not needed.

---

## 4. What changed in each app

### `wfb`

1. Dockerfile now installs Node/Yarn toolchain but defers dependency installation to runtime.
2. Added `bin/docker-entrypoint` lock-based install flow.
3. Added `webpack` service, HMR config, healthchecks, and cache volumes.

### `n2r`

1. Applied the same Dockerfile + entrypoint + compose + webpacker pattern.
2. Preserved project-specific env keys (`DATABASE_HOST` etc.) while adopting shared dev-loop improvements.

### `turtle`

1. Applied the same pattern with two project-specific adaptations:
2. `ensure_yarn` includes `--ignore-engines`.
3. `BUNDLE_APP_CONFIG` uses `$app/.bundle` to prevent permission issues.

---

## 5. Operational checklist (copy/paste)

Use this to migrate another Rails + Docker project.

1. Add `bin/docker-entrypoint` with lock-based `bundle`/`yarn` checks.
2. Set Docker `ENTRYPOINT` to that script.
3. Remove build-time dependency install commands from `Dockerfile`.
4. Add named volumes for `bundle`, `node_modules`, and `yarn_cache`.
5. Add dedicated `webpack` service and expose `3035`.
6. Update `webpacker.yml` dev server host to `webpack` and enable `hmr`.
7. Add `healthcheck` to stateful dependencies and use `depends_on: condition: service_healthy`.
8. Disable unnecessary Yarn startup checks on worker-like services with `AUTO_YARN_INSTALL=0`.

---

## 6. Trade-offs and caveats

1. Startup still performs dependency checks, so first boot can be slow.
2. Native gem compile time (for example `grpc`) can still dominate some workflows.
3. Long-term reproducibility still depends on lockfiles and pinned tool versions.
4. For production images, keep precompile/build optimization in a dedicated production Dockerfile path.

---

## 7. Result

The workflow is now optimized for iterative development instead of immutable image rebuilding.

Practical impact:

1. `Gemfile.lock` changes apply on next container start without image rebuild.
2. Yarn reuse is significantly better with persisted caches and install gating.
3. Frontend edits get immediate feedback through dedicated webpack HMR service.

For Rails teams using Docker as the default dev runtime, this pattern is low-risk and high-impact.
