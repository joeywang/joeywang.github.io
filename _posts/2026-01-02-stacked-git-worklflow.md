---
title: "Stacked Git: a Patch-Stack Workflow on Top of Git"
date: 2026-01-02
tags: ["git", "stgit", "productivity", "workflow"]
categories: [Engineering]
description: "Stacked Git (StGit) separates the messy work of thinking through code from the clean history Git commits are for, using a patch-stack workflow."
layout: post
---

<audio controls preload="metadata" src="/assets/audio/stacked-git-worklflow-summary.ogg">
  Your browser does not support the audio element.
</audio>

Most Git workflows are optimized for sharing code, not for thinking while coding. That mismatch is the root cause of messy commits, endless rebases, and painful code reviews. Stacked Git (StGit) is a patch-stack workflow on top of Git that fixes this without giving up Git compatibility.

## The core problem with a plain Git workflow

Git commits are immutable history units. Development work is not: it's non-linear, exploratory, frequently reordered, and revised many times before review.

Typical pain points: "I should have refactored first," "this commit mixes three unrelated changes," "the reviewer wants a small change in commit #3," "I need to temporarily remove this change to debug."

Git's answer to all of these is interactive rebase, stashing, resetting, commit squashing, and a fair amount of mental gymnastics. Git is doing its job. We're just using it for the wrong phase of the work.

## The key insight: commits are not ideas

During development you think in ideas; Git stores commits. Those are not the same unit, and forcing one into the other is where the friction comes from.

## Enter Stacked Git (StGit)

StGit adds a lightweight abstraction on top of Git: patches, arranged as a stack. Each patch represents one logical idea. You work in patches, reorder them, edit them, and temporarily disable them, and only convert them into Git commits once you're ready to share.

## Mental model: Git vs StGit

### Traditional Git

```
A --- B --- C --- D   (commits are fixed)
```

Reordering or editing history requires rewriting everything after the change.

### Stacked Git

```
Base commit
   │
   ├─ Patch: refactor
   ├─ Patch: feature
   ├─ Patch: tests
```

Patches are movable, editable, and applied independently. Git commits get generated later, once the shape of the change is settled.

## Under the hood: what StGit actually does

StGit stores patches as metadata, applies them on top of a Git branch, and keeps Git history clean and linear underneath. You are not replacing Git, you're adding a layer for development ergonomics.

## Initial setup

```bash
stg init
```

This enables StGit on the current branch.

Check status:

```bash
stg series
```

## Basic daily workflow

### 1. Start a new logical change

```bash
stg new refactor-api
```

Make changes, then record them:

```bash
stg refresh
```

Think of `stg refresh` as "update this patch."

### 2. Stack another idea on top

```bash
stg new add-endpoint
```

```bash
stg refresh
```

Add tests:

```bash
stg new tests
stg refresh
```

View the stack:

```bash
stg series
```

```
+ refactor-api
+ add-endpoint
+ tests
```

Each line is one clean, reviewable idea.

## Reordering work without a rebase

Real life happens: "that refactor should have happened first." With plain Git, that's an interactive rebase. With StGit:

```bash
stg float refactor-api
```

That's it.

### Conceptual diagram

```
Before:
  refactor
  feature
  tests

After float:
  refactor
  feature
  tests
```

The stack adjusts safely and automatically.

## Temporarily removing a change to debug

Suspect a patch is causing a bug?

```bash
stg pop add-endpoint
```

If the bug is gone, that confirms it. Restore it with:

```bash
stg push add-endpoint
```

No stash, no branch, no reset.

## Fixing reviewer comments without touching unrelated code

Say the reviewer wants a change to validation logic that lives in `add-endpoint`:

```bash
stg goto add-endpoint
# edit code
stg refresh
```

Everything above it re-applies automatically. This is where StGit earns its keep.

## Switching tasks without a branch explosion

Mid-feature, an urgent bug appears.

```bash
stg pop feature-x
stg new hotfix-null-check
stg refresh
```

Export just the fix:

```bash
stg export --commit hotfix-null-check
```

Resume work:

```bash
stg pop hotfix-null-check
stg push feature-x
```

## From patches to Git commits

When ready to share, export patches as commits:

```bash
stg export --commit
```

Each patch becomes one Git commit. To squash selectively before opening a PR:

```bash
stg squash refactor-api add-endpoint
```

## Development vs sharing

```
Development phase:
  [patch][patch][patch]

Sharing phase:
  [commit][commit]
```

StGit optimizes development. Git optimizes distribution. Use each for what it's good at.

## Recommended alias setup

```bash
git config --global alias.ss "!stg series"
git config --global alias.sn "!stg new"
git config --global alias.sr "!stg refresh"
git config --global alias.sp "!stg pop"
git config --global alias.spu "!stg push"
```

Now StGit feels native:

```bash
git sn feature-x
git sr
git ss
```

## When StGit is especially valuable

Long-lived feature branches, heavy refactors, frequent review iteration, and frequent context switching are where it pays off most. It's also just a better fit for anyone who cares about a clean, linear history.

Git commits are for history. StGit patches are for thinking. Once those two concerns are separated, code review stops being a negotiation over commit boundaries and goes back to being a review of the code.

