---
layout: post
title: Migrating a Rails App from Yarn + Webpacker to pnpm + Vite
date: 2026-01-21
categories: Rails
---
# Migrating a Rails App from Yarn + Webpacker to pnpm + Vite

We recently migrated a Rails application from a legacy JavaScript toolchain (`yarn` + `webpacker`) to a modern stack (`pnpm` + `vite`). This write-up captures the exact migration path, the pitfalls we hit, and the fixes that made production stable.

If your app still runs Webpacker, this can save you a lot of trial and error.

## Why We Migrated

Webpacker served Rails apps well for years, but it brings long compile times and more config friction than modern bundlers. We wanted:

- Faster builds in CI and Docker.
- Cleaner dependency management and reproducibility.
- Better developer experience for frontend iteration.
- A simpler path for modern JS and CSS bundling in Rails.

Switching to `pnpm` and `vite` delivered all four.

## Migration Goals

We defined concrete goals before touching production:

- Remove all yarn/npm coupling from CI, Docker, and Rails tasks.
- Replace Webpacker with Vite end-to-end.
- Keep production output deterministic for hashed assets.
- Ensure both local and cloud builds pass consistently.

## Step 1: Move Package Management to pnpm

### 1.1 Set pnpm as the package manager

In `package.json`, add:

```json
"packageManager": "pnpm@10.29.3"
```

Pinning the version keeps local, CI, and Docker aligned.

### 1.2 Replace yarn assumptions in Rails workflows

Rails/Webpacker-era tooling often assumes `bin/yarn` exists. During migration, we created a `bin/pnpm` helper and aligned scripts so Rails build tasks no longer require yarn.

### 1.3 Update CI and Docker to use pnpm

Every build surface must agree:

- GitHub Actions / CI jobs use `pnpm install` and `pnpm build`.
- Docker build stages install pnpm and run `pnpm build`.
- No leftover `yarn install`, `yarn build`, or `webpacker:compile` assumptions.

## Step 2: Replace Webpacker with Vite

### 2.1 Add Vite tooling

Install Vite and plugin:

- `vite`
- `vite-plugin-ruby`

Add config files:

- `/Users/joeyw/public_html/cms/config/vite.json`
- `/Users/joeyw/public_html/cms/vite.config.mjs`

### 2.2 Migrate layout helpers

Replace Webpacker tags with Vite helpers in layouts:

- Use `vite_client_tag` in development.
- Use `vite_javascript_tag 'application'` for entrypoint loading.

This lets Vite and Rails map hashed assets correctly through the manifest.

### 2.3 Migrate entrypoints and Stimulus loading

Move JS packs from Webpacker conventions to Vite-compatible entrypoints and update controller auto-loading to Vite patterns.

## Step 3: Fix Dependency Resolution Gaps (pnpm Is Stricter)

`pnpm` is stricter than Yarn’s hoisting model. That is a good thing, but it reveals undeclared dependencies immediately.

We had two concrete failures:

### 3.1 Missing Material component packages

Rollup failed resolving `@material/ripple` from a controller import. Fix was to add missing direct dependencies explicitly in `package.json`:

- `@material/ripple`
- `@material/list`
- `@material/menu-surface`

### 3.2 Missing PostCSS packages

Build failed loading `postcss.config.js` because `postcss-import` was not declared.

We added explicit dev dependencies:

- `postcss`
- `postcss-import`
- `postcss-flexbugs-fixes`
- `postcss-preset-env`

Key lesson: with pnpm, if your config references a package, declare it directly.

## Step 4: Docker and Cloud Build Hardening

This phase mattered as much as code migration.

### 4.1 Avoid `corepack` dependency in Docker images

Some images did not include `corepack`, causing:

`/bin/sh: corepack: not found`

We standardized Dockerfiles to install pnpm explicitly:

```bash
npm install -g pnpm@10.29.3
```

Applied consistently across:

- `/Users/joeyw/public_html/cms/Dockerfile`
- `/Users/joeyw/public_html/cms/Dockerfile.prod`
- `/Users/joeyw/public_html/cms/Dockerfile.slim`
- `/Users/joeyw/public_html/cms/Dockerfile.alpine`

### 4.2 Prevent recursive Vite builds

At one point, `package.json` had:

```json
"build": "bundle exec vite build"
```

This caused a recursion loop in cloud builds:

1. `pnpm build` calls `bundle exec vite build`
2. `vite_ruby` calls package manager build
3. package manager runs `pnpm build` again

Symptom: repeated `Building with Vite ⚡️` lines.

Fix:

```json
"build": "vite build",
"dev": "vite dev"
```

Use direct Vite CLI in npm scripts. Keep Rails orchestration in Rails tasks when needed.

### 4.3 Install dev dependencies in builder stage

Vite/PostCSS live in `devDependencies`. If Docker uses `pnpm install --prod` before frontend build, asset compilation fails.

We changed builder stages to:

- `pnpm install --frozen-lockfile` (include dev deps)
- `pnpm build`
- remove `node_modules` afterward to keep image lean

## Step 5: Validate Runtime Asset Delivery (Avoid 404 on Hashed CSS)

Even if build succeeds, runtime can still 404 hashed files.

We diagnosed a real-world issue where HTML referenced a new hash but requests sometimes hit pods with an older image.

Root cause pattern:

- Service selector sends traffic to multiple web deployments.
- Not all deployments are rolled to the same image tag.
- Hashed asset mismatch yields intermittent 404.

Mitigation:

- Roll all web deployments together.
- Or route service traffic to one deployment group at a time.
- Ensure deploy scripts do not exclude one active deployment from image updates.

## Benefits After Migration

After stabilizing the migration, we saw practical gains:

- Faster and cleaner frontend build flow.
- Deterministic dependency behavior with pnpm lockfile fidelity.
- Easier debugging because missing deps fail early and explicitly.
- Simpler frontend config than legacy Webpacker stacks.
- Better long-term compatibility with modern JS tooling.

## Migration Checklist You Can Reuse

- [ ] Add `packageManager` and pin pnpm version.
- [ ] Remove yarn assumptions from scripts, binstubs, CI, and Docker.
- [ ] Add Vite config and migrate layout helpers.
- [ ] Migrate entrypoints/controllers from Webpacker patterns.
- [ ] Add explicit dependencies revealed by pnpm strict resolution.
- [ ] Ensure PostCSS plugins are declared in `package.json`.
- [ ] Use direct `vite build` in package scripts.
- [ ] In Docker builder, install dev deps before Vite build.
- [ ] Make pnpm installation Docker-image-safe (avoid relying on corepack).
- [ ] Validate all production web pods serve the same asset hash set.

## Final Thoughts

The migration is very manageable if you treat it as an end-to-end platform change, not just a frontend package swap. Most failures happen at integration boundaries: Docker, CI, deploy scripts, and runtime traffic distribution.

Once those are aligned, `pnpm + vite` is a clear upgrade over `yarn + webpacker` for Rails apps that still carry legacy asset tooling.

