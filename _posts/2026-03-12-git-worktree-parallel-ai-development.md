---
layout: post
title: "Git Worktree for Parallel AI Development"
date: 2026-03-12
tags: [git, git-worktree, ai, rails, productivity, development]
categories: [Development, AI, Tools]
description: "How to use git worktree to run parallel AI coding sessions safely, with practical patterns for isolating gems, databases, ports, and runtime state."
---

# Git Worktree for Parallel AI Development

If you use AI coding agents seriously, you run into the same problem pretty quickly:

- one agent is fixing a bug
- another is writing tests
- you still want your own shell open for review
- and all of it is happening against the same repository

The lazy solution is branch switching plus `git stash`. That works right up until it doesn't. You forget what was stashed, an agent overwrites your half-finished change, or you stop one experiment because another task needs the branch.

`git worktree` is the tool that makes this sane.

It lets one Git repository have multiple working directories, each checked out to a different branch. You keep a stable tree for your main work, then spin up extra trees for experiments, reviews, or AI agents. Same repository history, separate directories, separate branch checkouts.

For modern AI development, that matters a lot. Agents work best when they have room to operate independently. Humans do too.

---

## What `git worktree` actually is

A normal Git repo gives you one working directory tied to one checked-out branch.

A worktree gives you this instead:

```text
repo main checkout        -> ~/src/myapp
bugfix worktree           -> ~/src/myapp-wt/bugfix-login
feature worktree          -> ~/src/myapp-wt/feature-billing
agent experiment worktree -> ~/src/myapp-wt/agent-refactor
```

These directories share the same Git object database, so Git does not need a full clone for each one. That is the key difference from copying the repo three times.

You get:

- separate files on disk
- separate checked-out branches
- shared repository history and objects
- much less disk and network overhead than repeated clones

So the mental model is simple:

> One repository. Many sandboxes.

---

## Why it fits AI-assisted development so well

Before AI agents, worktrees were already useful. With agents, they become a default tool.

Here is the pattern I keep coming back to:

1. keep your main worktree clean and review-focused
2. create one worktree per task or agent
3. let each agent operate inside its own directory
4. diff, test, and merge the result back when it proves itself

That gives you a few concrete advantages.

### 1. No branch thrashing

You do not need to stop what you are doing just because an agent needs a different branch.

### 2. Safer parallel experimentation

One agent can try a large refactor while another writes a migration or test fix. Their file edits do not collide locally because they are not touching the same working directory.

### 3. Better review discipline

Each worktree tends to map to one idea. That makes it easier to review what the agent actually changed instead of untangling a mixed branch.

### 4. Less "agent damaged my local state"

The Git state is isolated by directory. The runtime state is not automatically isolated, but at least the file tree is. That is already a huge step forward.

---

## Core commands you actually need

You do not need much to become productive with worktrees.

### Create a new worktree for a new branch

```bash
git worktree add ../myapp-wt/feature-auth -b feature/auth
```

This creates:

- a new directory at `../myapp-wt/feature-auth`
- a new branch called `feature/auth`
- that branch checked out inside the new directory

### Create a worktree for an existing branch

```bash
git worktree add ../myapp-wt/fix-timeouts fix/timeouts
```

### See all worktrees

```bash
git worktree list
```

### Remove a worktree when done

```bash
git worktree remove ../myapp-wt/feature-auth
```

### Clean up stale metadata

```bash
git worktree prune
```

### Prevent accidental removal

Useful if a long-running agent or remote machine is using the tree:

```bash
git worktree lock ../myapp-wt/feature-auth
```

And later:

```bash
git worktree unlock ../myapp-wt/feature-auth
```

That is enough for day-to-day use.

---

## A practical workflow for human + agent collaboration

Say your main repo lives here:

```bash
~/src/myapp
```

Create a sibling directory for worktrees:

```bash
mkdir -p ~/src/myapp-wt
```

Now spawn task-specific trees:

```bash
cd ~/src/myapp
git worktree add ../myapp-wt/bugfix-login -b bugfix/login
git worktree add ../myapp-wt/add-billing-tests -b test/billing
git worktree add ../myapp-wt/agent-refactor -b chore/refactor-payments
```

Then assign them intentionally:

- `bugfix-login`: you fix the production bug
- `add-billing-tests`: one agent writes tests
- `agent-refactor`: another agent explores a cleanup

At the end, each worktree has its own diff, commit history, and test results. That is much cleaner than running everything in one checkout and hoping for the best.

---

## The part people miss: Git is isolated, runtime state usually is not

This is where most worktree guides stop too early.

`git worktree` isolates the checked-out files. It does **not** automatically isolate:

- Ruby gems
- `node_modules`
- database names
- Redis databases
- ports
- `tmp/` and PID files
- logs
- Docker Compose project names
- `.env` or local secrets files

If you ignore that, parallel AI agents will still trip over each other. Not through Git this time, but through the app runtime.

For a Rails app, these are the usual failure modes:

- one worktree runs `bundle install` and changes shared gem state
- two servers both want port `3000`
- two Sidekiq processes share the same Redis namespace
- test runs stomp on the same development database
- `tmp/pids/server.pid` blocks the next boot
- Docker volumes get reused in surprising ways

So the real trick is:

> use worktrees for source isolation, then add explicit runtime isolation on top.

---

## Gem isolation: when to share and when not to

There are two valid strategies for gems.

### Option 1: Share gems for speed

If all worktrees stay on roughly the same branch family and use the same `Gemfile.lock`, sharing gems is usually fine.

Example:

```bash
bundle config set path /Users/joeyw/.bundle/myapp
```

This is fast and disk-efficient. For short-lived agent branches, it is often enough.

### Option 2: Isolate gems per worktree

If different worktrees may modify `Gemfile.lock`, isolation is safer.

Example:

```bash
bundle config set path vendor/bundle
```

Now each worktree keeps its own installed gems under its own directory. That costs more disk space, but avoids weird cross-branch dependency mismatches.

My rule is simple:

- same lockfile, shared gems are okay
- changing dependencies, isolate per worktree

For AI agents, I lean toward isolation if the task is exploratory. Agents are very good at "just one dependency change" turning into five.

---

## Database isolation for Rails worktrees

Database isolation is the part that matters most if you want parallel agents to actually be useful.

If every worktree points at the same development database, then your sandboxes are not really sandboxes.

The clean pattern is:

- one development database per worktree
- one test database per worktree
- predictable names derived from the worktree name

For example, if the worktree directory is `bugfix-login`, use:

```text
myapp_bugfix_login_development
myapp_bugfix_login_test
```

Then run:

```bash
bin/rails db:prepare
```

inside that worktree.

### Example with environment variables

You can drive this with `DATABASE_URL`:

```bash
export WORKTREE_NAME=bugfix_login
export DATABASE_URL=postgres://localhost/myapp_${WORKTREE_NAME}_development
export TEST_DATABASE_URL=postgres://localhost/myapp_${WORKTREE_NAME}_test
bin/rails db:prepare
```

If your app uses `config/database.yml`, you can interpolate the names there:

```yaml
development:
  adapter: postgresql
  database: <%= ENV.fetch("DB_NAME", "myapp_development") %>

test:
  adapter: postgresql
  database: <%= ENV.fetch("TEST_DB_NAME", "myapp_test") %>
```

Then each worktree exports a different `DB_NAME` and `TEST_DB_NAME`.

That one change removes a lot of pain.

---

## Ports, Redis, and process files

Once you isolate the database, the next collisions usually come from ports and process state.

I like giving each worktree a small local env file with predictable offsets:

```bash
export APP_PORT=3101
export VITE_PORT=4101
export REDIS_DB=11
export WORKTREE_NAME=bugfix_login
export DB_NAME=myapp_bugfix_login_development
export TEST_DB_NAME=myapp_bugfix_login_test
```

That helps with:

- Rails server port conflicts
- frontend dev server conflicts
- Sidekiq or cache isolation through separate Redis DBs or namespaces
- keeping logs easier to identify

For process files, make sure your app does not write to a shared absolute location. Prefer paths inside the current worktree:

```text
tmp/pids/
tmp/cache/
log/development.log
```

That usually happens naturally if each server starts inside its own worktree, but it is worth checking scripts and Procfiles for hard-coded paths.

---

## Docker Compose: the hidden shared-state trap

If you run Rails through Docker Compose, worktrees still help, but only if Compose resources are isolated too.

By default, different directories often produce different project names automatically. But I would not rely on accidental behavior for agent workflows. Be explicit.

Set a unique `COMPOSE_PROJECT_NAME` per worktree:

```bash
export COMPOSE_PROJECT_NAME=myapp_bugfix_login
docker compose up
```

That isolates:

- container names
- networks
- volumes

If you do not do this, two worktrees may silently share volumes or collide on service names. That gets confusing fast.

You will still need different published host ports if multiple stacks run at once:

```yaml
ports:
  - "${APP_PORT}:3000"
```

Then each worktree can define a different `APP_PORT`.

---

## A bootstrap script for new worktrees

This is where worktrees go from "nice Git trick" to "real development system".

Create a small setup script that derives runtime names from the current directory. Then every worktree can bootstrap itself with one command.

Example:

```bash
#!/usr/bin/env bash
set -euo pipefail

worktree_name="$(basename "$PWD" | tr '-' '_' | tr '.' '_')"

export BUNDLE_PATH="${PWD}/vendor/bundle"
export DB_NAME="myapp_${worktree_name}_development"
export TEST_DB_NAME="myapp_${worktree_name}_test"
export APP_PORT="${APP_PORT:-3000}"
export REDIS_DB="${REDIS_DB:-0}"
export COMPOSE_PROJECT_NAME="myapp_${worktree_name}"

bundle install
bin/rails db:prepare
```

That is a good start, but for real parallel use you usually want deterministic per-worktree port allocation too.

For example, keep a tiny `.env.worktree` in each tree:

```bash
APP_PORT=3101
VITE_PORT=4101
REDIS_DB=11
```

Then source it during setup:

```bash
set -a
[ -f .env.worktree ] && . ./.env.worktree
set +a
```

This keeps the generated names predictable without overengineering the bootstrap.

---

## A good pattern for AI agents

Here is the pattern I would actually recommend for a Rails team using AI heavily.

### 1. Keep one canonical main worktree

Use it for:

- reviewing diffs
- rebasing
- final test runs
- merging

Try not to let agents write there.

### 2. Create one worktree per agent task

Examples:

- `wt-fix-login-timeout`
- `wt-write-request-specs`
- `wt-upgrade-rubocop`

Make the directory name itself carry the task context.

### 3. Bootstrap each worktree before handing it to an agent

That means:

- install gems
- prepare the correct database
- assign ports
- set Redis namespace or DB
- confirm the app boots

Do not ask the agent to figure out all environment isolation from scratch every time. Give it a stable sandbox.

### 4. Keep agent tasks narrow

Worktrees help with isolation, but they do not magically solve coordination. If three agents all edit the same service object, you still created a merge problem.

Use worktrees to isolate task execution, not to ignore task decomposition.

### 5. Delete aggressively

When a branch is merged or abandoned:

```bash
git worktree remove ../myapp-wt/agent-refactor
git branch -D chore/refactor-payments
git worktree prune
```

Treat worktrees as disposable.

---

## Common mistakes

### Putting worktrees inside the main repository without thinking

You can do it, but sibling directories are easier to reason about and easier to clean up.

### Sharing one development database across all worktrees

This defeats the whole point of isolated experimentation.

### Assuming gem sharing is always safe

It is safe until two branches disagree on dependencies.

### Forgetting Redis and ports

This is the classic "Git is isolated, app runtime is not" problem.

### Letting an agent reuse your personal scratch branch

Give the agent its own branch and its own worktree. Branch hygiene matters more once agents enter the picture.

---

## When not to use worktrees

Worktrees are great, but not universal.

I would skip them when:

- the task is a tiny one-file edit
- the agent only needs read-only repo context
- your app bootstrap is so heavy that spinning a new environment costs more than the isolation is worth

But once you reach parallel coding, parallel testing, or agent-based experimentation, worktrees usually pay for themselves immediately.

---

## Final thought

`git worktree` is one of those Git features that feels optional until your workflow changes. In a human-only flow, it is convenient. In an AI-assisted flow, it starts to feel structural.

The reason is simple: modern development is becoming multi-threaded.

You are reviewing one branch, an agent is patching another, CI is validating a third idea, and maybe a second agent is trying something risky that should never touch your main checkout.

Worktrees give each thread a real place to live.

Just remember the full story:

- Git isolation comes from `git worktree`
- reliable parallel execution comes from isolating runtime state too

If you handle both, worktrees become a very practical foundation for running multiple agents against the same codebase without turning your laptop into a shared disaster zone.
