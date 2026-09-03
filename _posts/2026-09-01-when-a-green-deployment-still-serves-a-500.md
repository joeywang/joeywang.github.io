---
layout: post
title: "When a Green Deployment Still Serves a 500"
description: "A REX production incident exposed the gap between a successful Kubernetes rollout and a working application. Here is what failed, how we recovered, and what we changed."
date: 2026-09-01 14:00:00 +0100
author: "Joey Wang"
tags: [ruby-on-rails, ci, deployment, reliability, webpacker, incident-response]
categories: [Engineering]
---

<audio controls preload="metadata" src="/assets/audio/when-a-green-deployment-still-serves-a-500-summary.ogg">
  Your browser does not support the audio element.
</audio>

A production deployment can be green and still be broken.

We recently deployed a new version of a Rails learning platform. The image built. The Kubernetes deployments rolled out. The pods became ready. The workers started.

Then somebody opened the login page and got a 500.

That is the kind of incident that makes a team question every green checkmark it has been relying on.

## The symptom

The first request to the application redirected to the login page as expected. The login page itself returned 500.

The Rails error was an asset lookup failure. The page expected a CSS entry such as `mypage.css`, but the Webpacker manifest did not contain it.

The Kubernetes view of the world looked healthy:

```text
rails       ready
migration   complete
scheduler   ready
worker      ready
```

The application view of the world was different:

```text
GET /login  -> 500
missing Webpacker asset -> mypage.css
```

Both statements were true. The pods were healthy enough to pass their readiness checks. The application was not healthy enough for a user to sign in.

## The first lesson: readiness is not availability

A readiness probe answers a narrow question: should this pod receive traffic?

It does not answer:

- Can the login page render?
- Did the compiled asset manifest contain the entries that the templates reference?
- Can the browser download the CSS and JavaScript?
- Can a user complete the first meaningful action?

Our rollout check was necessary, but it was not sufficient. We had verified process health, not application behaviour.

The missing check was small:

```text
GET /status -> 200
GET /login  -> 200
critical CSS/JS assets -> 200
```

A deployment that cannot pass those checks should not be reported as successful.

## What made the failure harder to diagnose

The application had recently moved its JavaScript dependencies from Yarn to pnpm. Webpacker 5 still carries assumptions about Yarn.

The production Docker build installed pnpm, but the old Webpacker Rake task still had a Yarn-oriented verification step. In addition, the build copied only part of the Rails configuration before compiling the assets. The pnpm-specific configuration was not reliably available at the point where Webpacker started.

There was another problem layered on top of that. The build command had been written in a form that allowed the asset compilation failure to be ignored:

```dockerfile
bundle exec rake webpacker:compile || true
```

That transformed a useful build failure into a bad image that looked successful.

The manifest check we added later made the situation visible:

```ruby
manifest = JSON.parse(File.read("public/assets/manifest.json"))
abort unless manifest.key?("mypage.css")
```

The right place to discover a missing asset is the builder, before the image is pushed or deployed. Not in a user's browser after the rollout.

## Recovery took too long

The first rollback path was also wrong for an incident.

Instead of switching Kubernetes back to an image that had already been built and verified, the rollback went through the production build process again. That meant waiting for dependency installation, native extensions, asset compilation, image creation, and rollout.

Rebuilding an old commit is useful when an old image no longer exists. It is a poor emergency rollback strategy when the known-good image is already in the registry.

The faster operation is an image switch guarded by the current version:

```text
expected current image: bad-sha
rollback image:        known-good-sha
```

If the cluster is no longer running the expected bad version, the rollback should stop rather than overwrite an unrelated change.

The rollback should then update the application, migration, scheduler, and worker deployments, wait for each rollout, and run the same application smoke checks used after deployment.

A rollback is not complete when `kubectl` accepts the command. It is complete when the service is serving the known-good image and the user-facing checks pass.

## The changes we made

We made the build and release path more conservative in four ways.

### 1. The asset build now fails closed

The production image no longer ignores Webpacker errors. The build must compile the assets and produce a manifest containing the critical login stylesheet.

The pnpm integration is explicit. The builder passes a known Webpack executable path to Webpacker and invokes the compiler without the old Yarn-only verification task.

This means a broken manifest stops the build. That is exactly what we want.

### 2. The deployment has an application smoke gate

After the migration and rollout, the release checks:

```text
/status
/login
critical CSS asset
critical JavaScript asset
```

A pod can be ready while an application is broken. The smoke gate checks the path a user actually takes.

This is not a replacement for feature tests. It is a fast last line of defence between deployment and traffic.

### 3. Rollback uses an existing immutable image

The rollback procedure now targets an existing image identified by its full commit SHA. It checks the current image before changing anything and waits for all selected deployments to become ready.

It does not rebuild the old source during the incident.

That distinction matters. Build pipelines optimise for repeatability. Emergency rollback optimises for time and a known result.

### 4. CI spends test time according to risk

We also changed the CI model. Not every change needs the same test scope.

A documentation-only change should not start a database and a long RSpec suite. A user-facing feature should run focused tests and a basic browser smoke. A database, dependency, CI, or shared test-support change should escalate to a broader suite.

The current levels are:

```text
L0  changed files and static checks
L1  affected tests
L2  basic E2E smoke
L3  full RSpec and integration tests
L4  full E2E
L5  performance tests
```

The promotion path from `main` to production remains strict. Faster feedback on a feature branch must not become weaker release confidence.

## Caching failures without lying to ourselves

The next part of this work is test-result reuse.

A failed test result is useful evidence. It can tell us which examples to rerun first. But a cached pass is not proof that a new commit is safe.

Our result context therefore includes more than a branch name:

- exact commit SHA;
- test suite and command;
- Ruby, Node, and pnpm versions;
- dependency lockfile hashes;
- schema and test configuration fingerprints.

A failed-example retry is allowed only when the context matches. The first attempt and retry remain separate in the CI report.

The rule is simple:

> Use cached failures to find the problem faster. Never use cached passes to bypass the required tests.

## What I would check next time

When a deployment reports success, I want to see evidence from three layers:

1. **Build:** the image contains the required runtime and compiled assets.
2. **Platform:** migrations and workloads roll out with the expected image SHA.
3. **Application:** `/login`, critical assets, and one meaningful user path work.

If one layer is missing, the release is only partially verified.

I also want a rollback drill. A rollback procedure that has never been exercised is a paragraph in a document, not an operational capability. The team should know which image is known good, how to switch to it, how long the operation takes, and what evidence proves recovery.

## The uncomfortable conclusion

The incident was not caused by one exotic failure. It came from ordinary assumptions lining up in the wrong direction:

- a package-manager migration left an older build tool assumption behind;
- the build tolerated a failed asset compilation;
- readiness checks did not exercise the login page;
- rollback rebuilt instead of switching to an existing image.

Each assumption was understandable in isolation. Together they produced a deployment that was green in the pipeline and broken for users.

The fix is not to add more green badges. It is to make each badge answer a precise question, fail when that question has a bad answer, and keep a fast path back to a version that has already worked.

That is the standard I want from production engineering: not the appearance of safety, but evidence that the system can start, serve a real request, and recover when the next change goes wrong.
