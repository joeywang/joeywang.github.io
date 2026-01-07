---
title: "Improving Daily Git Workflow with Stacked Git (StGit)"
date: 2026-01-02
tags: ["git", "workflow", "productivity", "stgit", "development"]
categories: ["Development", "Tools"]
description: "Enhance your daily Git workflow with Stacked Git (StGit) for better commit management and productivity."
layout: post
---

# Improving Daily Git Workflow with Stacked Git (StGit)

> *Stop fighting commits. Start stacking ideas.*

Most Git workflows are optimized for **sharing code**, not for **thinking while coding**.
That mismatch is the root cause of messy commits, endless rebases, and painful code reviews.

This article introduces **Stacked Git (StGit)** — a patch-stack–based workflow that dramatically improves day-to-day development productivity while staying fully compatible with Git.

---

## The Core Problem with Traditional Git Workflow

Git commits are immutable history units.
But during development, our work is:

* non-linear
* exploratory
* frequently reordered
* revised many times before review

### Typical pain points

* “I should have refactored first”
* “This commit mixes 3 unrelated changes”
* “Reviewer wants a small change in commit #3”
* “I need to temporarily remove this change to debug”

### What Git forces you to do

* Interactive rebase
* Stashing
* Resetting
* Commit squashing
* Mental gymnastics

Git is doing its job — **we’re using it for the wrong phase**.

---

## The Key Insight: Commits ≠ Ideas

During development:

* You think in **ideas**
* Git stores **commits**

These are not the same thing.

---

## Enter Stacked Git (StGit)

**StGit** introduces a lightweight abstraction on top of Git:

> **Patches**, arranged as a **stack**

Each patch represents **one logical idea**.

You:

* work in patches
* reorder patches
* edit patches
* temporarily disable patches

Only when ready do you convert patches into Git commits.

---

## Mental Model: Git vs StGit

### Traditional Git

```
A --- B --- C --- D   (commits are fixed)
```

Reordering or editing history requires rewriting everything after the change.

---

### Stacked Git

```
Base commit
   │
   ├─ Patch: refactor
   ├─ Patch: feature
   ├─ Patch: tests
```

Patches are:

* movable
* editable
* independently applied

Git commits are generated **later**.

---

## Under the Hood: What StGit Actually Does

StGit:

* stores patches as metadata
* applies them on top of a Git branch
* keeps Git history clean and linear

You are **not replacing Git** — you are adding a layer for development ergonomics.

---

## Initial Setup

```bash
stg init
```

This enables StGit on the current branch.

Check status:

```bash
stg series
```

---

## Basic Daily Workflow

### 1. Start a new logical change

```bash
stg new refactor-api
```

Make changes, then record them:

```bash
stg refresh
```

> Think of `stg refresh` as “update this patch”.

---

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

Each line is one **clean, reviewable idea**.

---

## Reordering Work (Without Rebase Hell)

Real life happens:

> “That refactor should have happened first.”

With Git: interactive rebase.
With StGit:

```bash
stg float refactor-api
```

That’s it.

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

The stack adjusts safely, automatically.

---

## Temporarily Removing a Change (Debugging Superpower)

Suspect a patch causes a bug?

```bash
stg pop add-endpoint
```

Bug gone? Confirmed.

Restore it:

```bash
stg push add-endpoint
```

No stash. No branch. No reset.

---

## Fixing Reviewer Comments (Surgically)

Reviewer says:

> “Please change validation logic.”

That logic lives in `add-endpoint`.

```bash
stg goto add-endpoint
# edit code
stg refresh
```

Everything above re-applies automatically.

This is **where StGit shines**.

---

## Switching Tasks Without Branch Explosion

Mid-feature, urgent bug appears.

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

---

## From Patches to Git Commits

When ready to share:

### Export patches as commits

```bash
stg export --commit
```

Each patch becomes one Git commit.

---

### Squash selectively

```bash
stg squash refactor-api add-endpoint
```

Perfect for clean PRs.

---

## Visual Summary: Development vs Sharing

```
Development phase:
  [patch][patch][patch]

Sharing phase:
  [commit][commit]
```

StGit optimizes **development**.
Git optimizes **distribution**.

Use both for what they’re best at.

---

## Recommended Alias Setup

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

---

## When StGit Is Especially Valuable

* Long-lived feature branches
* Heavy refactors
* Frequent review iteration
* Context switching
* Senior engineers who care about clean history

---

## Final Takeaway

> **Git commits are for history.
> StGit patches are for thinking.**

Once you separate those concerns, your workflow becomes:

* calmer
* cleaner
* faster

And code reviews become a joy instead of a negotiation.

