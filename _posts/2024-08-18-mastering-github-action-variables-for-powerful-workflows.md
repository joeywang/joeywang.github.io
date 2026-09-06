---
layout: post
title: "GitHub Actions Variables: env, Contexts, Secrets, and Matrix"
description: "How GitHub Actions variables work in practice: env blocks, context variables, secrets, matrix strategies, and passing step outputs between steps."
date: 2024-08-18 00:00 +0000
categories: [DevOps]
tags: [github-actions, ci, devops]
---

<audio controls preload="metadata" src="/assets/audio/mastering-github-action-variables-for-powerful-workflows-summary.ogg">
  Your browser does not support the audio element.
</audio>


Most GitHub Actions workflows I review misuse variables in one of two ways: hardcoding values that should be dynamic, or reaching for a context expression where a plain shell variable would do. The distinction matters because each kind of variable lives in a different place and is resolved at a different time. Here is how they fit together.

## Environment variables

Environment variables are key-value pairs available to all steps in a job. They can be defined at the workflow, job, or step level.

```yaml
env:
  MY_ENV: myenv
```

You can access these variables using the `${{ env.MY_ENV }}` syntax in expressions, or as `$MY_ENV` inside a `run` script.

## Repository context variables

Context variables provide information about the repository and the event that triggered the run. For example:

- `github.repository_owner`: the owner of the repository.
- `github.repository`: the owner and repository name, as `owner/repo`.
- `github.actor`: the username of the person or app that initiated the workflow.

These are resolved by GitHub before the step runs, so they are useful for setting environment variables dynamically or passing data between steps.

```yaml
${{ github.actor }} # usage example
```

## Secrets

Secrets are encrypted values for sensitive information such as tokens or passwords. They are defined in the repository settings and referenced with the `${{ secrets.GITHUB_TOKEN }}` syntax. When calling a reusable workflow, you pass them through explicitly:

```yaml
secrets:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Shell parameter expansion on GITHUB_REPOSITORY

The `GITHUB_REPOSITORY` environment variable contains the owner and repository name. Inside a `run` script, shell parameter expansion splits it without any extra action:

```yaml
${GITHUB_REPOSITORY%/*} # extract owner
${GITHUB_REPOSITORY#*/} # extract repo name
```

## Matrix strategy

The matrix strategy runs a job once per combination of values. This is the standard way to test against multiple versions of a dependency or build multiple configurations.

```yaml
matrix:
  version: ['4.4.8', '4.5.3']
```

You can access the matrix variables using the `${{ matrix.version }}` syntax.

## Passing values between steps

A shell variable set inside a `run` script dies with that script. To make a value visible to later steps, write it to `$GITHUB_OUTPUT` and read it back through the `steps` context:

```yaml
steps:
  - id: "my_step"
    run: |
      echo "my_var=Hello World" >> "$GITHUB_OUTPUT"
      echo ${{ matrix.version }}
  - run: |
      echo "${{ steps.my_step.outputs.my_var }}"
```

The `id` on the producing step is what makes `steps.my_step.outputs.my_var` addressable. Forgetting the `id`, or setting a plain shell variable and expecting it to survive, are the two most common failure modes here.

## The short version

Use `env` for values shared within a job, contexts for anything GitHub already knows, secrets for credentials, matrix for fan-out, and `$GITHUB_OUTPUT` for step-to-step data. Once you know which layer a value belongs to, the workflow syntax mostly writes itself.
