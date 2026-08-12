---
layout: post
title: "Orchestrating Hermes with Local Gemma: Cheap Routing, Delegation, and Safe Rails Workflows"
description: "A practical guide to using Hermes Agent with a local Gemma model for routine coding work, while reserving cloud models for tasks that genuinely need them."
date: 2026-08-12 14:00:00 +0100
author: "Joey Wang"
tags: [hermes, agents, gemma, local-ai, coding-agent, rails, orchestration]
categories: [AI, Engineering]
---

# Orchestrating Hermes with Local Gemma

<audio controls preload="metadata" src="/assets/audio/orchestrating-hermes-local-gemma-summary.ogg">
  Your browser does not support the audio element.
</audio>

A useful coding agent is more than a language model with a terminal attached. It needs a workspace, tools, approval boundaries, a way to delegate, and a recovery plan for the cases where the first attempt stalls.

This post documents my current Hermes setup on an Apple Silicon Mac and the practical lesson from the experiment:

> **Local Gemma is already good at deciding which engineering workflow a request needs. Automatic per-request model switching is not yet active in this Hermes installation, so explicit local-session selection is the reliable path today.**

The examples use a Rails application under a placeholder path. They are written to be safe defaults: inspect first, show the plan, approve dependency changes, then verify the result.

## The architecture

The setup has three model paths:

```text
┌──────────────────────────────────────────────────────────┐
│ Main Hermes conversation                                 │
│ Cloud model when broad reasoning or difficult context    │
└───────────────────────┬──────────────────────────────────┘
                        │ delegation, when requested/used
                        ▼
┌──────────────────────────────────────────────────────────┐
│ Local Gemma through LM Studio                           │
│ google/gemma-4-e2b                                      │
│ http://127.0.0.1:1234/v1                                │
└───────────────────────┬──────────────────────────────────┘
                        │ file + terminal tools
                        ▼
┌──────────────────────────────────────────────────────────┐
│ Local project workspace                                  │
│ /path/to/<application>                                   │
└──────────────────────────────────────────────────────────┘
```

Hermes is the runtime. LM Studio provides an OpenAI-compatible local endpoint. Gemma makes decisions and proposes actions. Hermes, not Gemma, executes tools and applies approval policy.

That separation matters. A model does not run `bundle update` by itself. The agent runtime executes the command, captures the output, gives it back to the model, and continues the loop.

## Runtime details

The local endpoint and model currently used are:

```text
Endpoint: http://127.0.0.1:1234/v1
Model:    google/gemma-4-e2b
Runtime:  LM Studio, local device
```

The Hermes configuration contains the local provider and alias:

```yaml
fallback_providers:
  - provider: custom
    model: google/gemma-4-e2b
    base_url: http://127.0.0.1:1234/v1
    api_mode: chat_completions

delegation:
  model: google/gemma-4-e2b
  provider: custom
  base_url: http://127.0.0.1:1234/v1

model_aliases:
  local-gemma:
    provider: custom
    model: google/gemma-4-e2b
    base_url: http://127.0.0.1:1234/v1
```

Check the effective configuration rather than assuming it:

```bash
hermes config path
hermes config get fallback_providers
hermes config get delegation
hermes config get model_aliases
hermes config check
```

Check LM Studio independently:

```bash
lms ls
lms ps
curl -sS http://127.0.0.1:1234/v1/models
```

The endpoint should list `google/gemma-4-e2b`. If it does not, Hermes cannot use the local model even if the YAML looks correct.

## The simplest cheap workflow: run the whole session locally

The most predictable form of cost control is not automatic routing. It is selecting the local model explicitly for a session:

```bash
hermes chat \
  --model local-gemma \
  --in "/path/to/my-rails-app" \
  --toolsets file,terminal \
  --reasoning low
```

For a one-shot inspection:

```bash
hermes chat \
  --model local-gemma \
  --in "/path/to/my-rails-app" \
  --toolsets file,terminal \
  --reasoning low \
  -q 'Inspect this Rails app. Identify the package managers, current dependency state, test commands, and any uncommitted changes. Do not modify files or run upgrades.'
```

This makes the model choice visible and auditable. It also avoids accidentally sending a routine maintenance request to an expensive cloud provider.

Use the real application path in place of `/path/to/my-rails-app`:

```bash
printf '%s\n' /path/to/projects/*
```

Do not assume that every directory under `/path/to/projects` is a Rails application. Let the agent inspect for `Gemfile`, `Gemfile.lock`, `package.json`, `yarn.lock`, `config/application.rb`, and the repository state.

## Example: Bundler and Yarn upgrade in a Rails app

A dependency upgrade is not a trivial “run two commands” task. It can change a lockfile, update transitive dependencies, expose incompatible Ruby versions, alter JavaScript build output, or require application changes.

Start with a read-only request:

```bash
hermes chat \
  --model local-gemma \
  --in "/path/to/my-rails-app" \
  --toolsets file,terminal \
  --reasoning low \
  -q 'Inspect this Rails repository for a routine dependency maintenance task. Determine whether it uses Bundler and Yarn, report the Ruby/Rails/Node/package-manager versions, inspect git status, identify the relevant upgrade commands, and propose a verification plan. Do not modify files and do not run bundle or yarn upgrade commands.'
```

A good response should first discover facts. Typical inspection commands include:

```bash
pwd
git status --short --branch
ruby --version
bundle --version
node --version
yarn --version
bundle check
bundle outdated --only-explicit || true
yarn outdated || true
```

The exact commands depend on the repository. In particular, do not use Yarn if the project actually uses npm or pnpm, and do not assume that `bundle update` is equivalent to updating one named gem.

Once the plan is reviewed, run a separate approved session or continue the same session with a clear boundary:

```bash
hermes chat \
  --model local-gemma \
  --in "/path/to/my-rails-app" \
  --toolsets file,terminal \
  --reasoning low \
  -q 'Now apply the approved dependency-maintenance plan. Update only the agreed Bundler and Yarn dependencies. Before each mutating command, show the exact command and its scope. Afterward inspect the diff and run the repository verification commands. Do not deploy, push, delete files, or change application code unless explicitly required and approved.'
```

The desired workflow is:

```text
inspect
  → identify package managers and scope
  → show exact commands
  → approve
  → update dependencies
  → inspect lockfile diff
  → run tests and build checks
  → report failures and remaining risk
```

For a narrow update, the commands may look like these, but the agent should verify the project first:

```bash
bundle update rails

yarn upgrade-interactive --latest
```

A broad upgrade is much riskier:

```bash
bundle update
yarn upgrade
```

Do not use broad commands merely because they are shorter. Lockfile churn makes failures harder to diagnose and rollbacks less focused.

## Approval boundaries

Keep normal Hermes approvals enabled. Avoid `--yolo` for dependency work:

```bash
# Safer default: approval prompts remain active
hermes chat --model local-gemma --in "/path/to/my-rails-app"

# Avoid this for upgrades unless you have a very specific reason:
# hermes chat --yolo ...
```

A useful prompt makes the boundary explicit:

```text
You may inspect files and run read-only diagnostics. Do not run mutating commands until I approve the exact command. Treat bundle update, yarn upgrade, database migrations, deployment, git commit, git push, file deletion, and changes outside this repository as mutating operations.
```

The local model is inexpensive, but an unsafe command is still unsafe. Lower inference cost should buy more inspection and smaller changes, not fewer controls.

## What delegation means in Hermes

Delegation is different from automatic routing.

- **Explicit model selection** chooses the model for the current Hermes session.
- **Delegation** lets the main agent ask a configured child model to handle a subtask.
- **Fallback** is provider failover when the primary model is unavailable.
- **Smart routing** would classify each request and choose a cheaper model automatically, but that feature is not active in this installed Hermes runtime.

The configured delegation model can be checked with:

```bash
hermes config get delegation
```

The important fields are:

```yaml
delegation:
  model: google/gemma-4-e2b
  provider: custom
  base_url: http://127.0.0.1:1234/v1
  max_iterations: 20
  max_concurrent_children: 1
  max_spawn_depth: 1
  orchestrator_enabled: false
  subagent_auto_approve: false
  default_toolsets: '["file", "terminal"]'
```

The local Gemma workflow test showed that it can classify common engineering tasks:

```text
bug fixing             → bug fixing
missing test suite     → test writing
README update          → documentation
duplicate code cleanup → refactoring
API vulnerability scan → security review
new CSV export         → feature implementation
vague cleanup request  → clarification
```

Measured result from seven prompts:

```text
Workflow routing:       7/7 correct
Response structure:     7/7 compliant
Detailed plan checks:   6/7 passed
```

The one detailed miss was in the security-review case: Gemma selected the correct workflow and asked for the missing API code, but did not explicitly include remediation in its plan. That is a useful limitation to know. Correct routing does not imply complete execution planning.

The raw test script and result are kept with the Hermes setup:

```text
<hermes-config-dir>/scripts/test_local_gemma_workflows.py
<hermes-config-dir>/docs/LOCAL-GEMMA-WORKFLOW-TEST.md
<hermes-config-dir>/test-results/local_gemma_workflow_results.json
```

Run it again with:

```bash
cd <hermes-config-dir>
python3 scripts/test_local_gemma_workflows.py
```

## Why automatic smart routing is not enabled here

The config contains a placeholder:

```yaml
smart_model_routing:
  enabled: false
  max_simple_chars: 160
  max_simple_words: 28
  cheap_model: {}
```

In this installed version, the option is written by setup but there is no active runtime implementation that reliably classifies every incoming task and switches the main model. Turning the flag on would create false confidence.

Until that runtime support exists, these are the practical routing policies:

### Policy A: local by default for maintenance

Use `local-gemma` for:

- dependency inspection;
- small bundle or Yarn updates;
- README and documentation edits;
- test scaffolding;
- simple refactors;
- repository status and diagnostics;
- preparing a plan for human approval.

### Policy B: cloud for difficult reasoning

Use the cloud model when the task involves:

- a large unfamiliar codebase;
- subtle production debugging;
- security-sensitive changes;
- difficult migrations;
- architecture decisions with broad consequences;
- interpreting many failures across services;
- work where the local model repeatedly gets stuck.

### Policy C: hybrid session

Start locally. If Gemma cannot progress, stop rather than letting it improvise. Capture the current state and restart with a cloud model using the local output as evidence:

```bash
hermes chat \
  --model local-gemma \
  --in "/path/to/my-rails-app" \
  --toolsets file,terminal \
  --reasoning low
```

Then, only if needed:

```bash
hermes chat \
  --in "/path/to/my-rails-app" \
  --toolsets file,terminal \
  --reasoning medium \
  -q 'Continue the dependency-maintenance investigation. Use the prior inspection notes below. Do not repeat completed commands. Identify the smallest safe next step and explain why it needs stronger reasoning. [paste notes]'
```

## The orchestration checklist

Before starting:

```bash
cd "$HOME/public_html/my-rails-app"
git status --short --branch
```

Ask the agent to establish:

- repository root;
- current branch and uncommitted changes;
- Ruby and Node versions;
- Bundler and JavaScript package manager;
- test, lint, and build commands;
- whether the working tree is safe to modify;
- the exact requested scope.

Before mutating:

- require a written plan;
- prefer named dependency updates over broad updates;
- show exact commands;
- confirm the lockfile and source files that may change;
- ensure no deployment or push is included;
- keep a rollback path through git.

After mutating:

```bash
git diff --stat
git diff -- Gemfile Gemfile.lock package.json yarn.lock
git status --short --branch
bundle check
yarn check --integrity || true
bundle exec rails test || bundle exec rspec
yarn test || true
yarn build || true
```

Use the commands the repository actually defines. The final report should separate:

```text
Changed:
Tests run:
Tests passed:
Tests failed:
Warnings:
Remaining risk:
Rollback:
```

## A reusable orchestration prompt

This prompt works well for routine Rails maintenance:

```text
You are operating in a Rails repository. Work as a cautious maintenance engineer.

Goal: inspect and, only after approval, perform the requested dependency update.

Rules:
1. Start with read-only inspection.
2. Identify the repository root and package managers from files, not assumptions.
3. Check git status before touching anything.
4. Report Ruby, Rails, Bundler, Node, Yarn/npm/pnpm versions when available.
5. Propose the smallest command that satisfies the request.
6. Do not run bundle update, yarn upgrade, migrations, deployment, commit, push, deletion, or commands outside the repository without explicit approval.
7. Before a mutating command, show the exact command and explain its scope.
8. After changes, inspect the diff and run the project's own tests, lint, and build checks.
9. Never claim a test passed unless you actually ran it.
10. If the request is ambiguous or the repository state is unsafe, stop and ask for clarification.

Requested task: inspect the app and prepare a plan for a Bundler and Yarn upgrade.
```

## The deeper lesson

The model is only one part of the system. Reliable orchestration comes from combining:

```text
model choice
+ workspace boundary
+ tool access
+ approval policy
+ iterative tool loop
+ verification
+ rollback
```

Local Gemma is attractive because it removes cost and network dependency from routine work. But the largest reliability gains do not come from model size alone. They come from giving the model a narrow task, a real workspace, explicit constraints, and a requirement to verify its own changes.

For my current setup, the practical rule is simple:

> **Start routine engineering work with local Gemma, keep the scope narrow, approve mutations, verify everything, and escalate to a cloud model only when the local path demonstrates that it needs help.**

This is not fully automatic orchestration yet. It is deliberate orchestration, and it is already useful.
