---
layout: post
title: "The Hard Part of AI PR Review Is Not Reading the Diff"
date: 2026-07-25 19:53:02 +0100
author: "Joey Wang"
description: "A practical look at Alibaba OpenCodeReview, why diff-only AI review is not enough, and how to use AI reviewers without trusting them too much."
tags: [ai, code-review, github-actions, devops, testing]
categories: [AI Engineering]
---

# The hard part of AI PR review is not reading the diff

AI code review sounds like an obvious win.

A pull request is text. LLMs read text. The bot can comment before a human even opens the page. It can catch repeated mistakes, missing checks, suspicious conditionals, forgotten tests, and obvious security smells without getting tired.

That is useful.

It is also not the same as reviewing the change.

A pull request is not just a diff. It is a small visible slice of a bigger system: call paths, test history, product intent, old incidents, feature flags, production constraints, and code that is ugly for a reason. The diff is where the change appears. It is not always where the risk lives.

Alibaba's [OpenCodeReview](https://github.com/alibaba/open-code-review) caught my attention because it treats AI review as something that needs engineering around it, not just a prompt around a patch. The project includes a benchmark built from real open-source pull requests and annotated issues from senior engineers. It also exposes a CLI, a GitHub Action, custom review rules, full-file scan mode, and delegation mode for coding agents.

That is the right direction. If we cannot measure what the AI reviewer missed, we are mostly measuring confidence and prose quality.

This post is partly about OpenCodeReview and partly about the harder problem behind it: how to make AI PR review useful without letting it become a noisy, overconfident reviewer that only saw the easy part.

## Why diff-only review is not enough

A diff answers one question:

> What changed?

A real review asks more questions:

- What is this code supposed to do?
- Which path reaches it?
- What changed outside this file?
- What tests ran?
- What was not tested?
- Is this change safe for the deployment target?
- Is the code ugly because nobody cleaned it up, or because an old client still depends on it?

A diff can show this:

```diff
-timeout: 30
+timeout: 5
```

The reviewer still needs to know where that timeout is used:

- user-facing request path;
- background job;
- payment callback;
- slow third-party API;
- retry wrapper;
- database transaction;
- batch import.

The line is the same. The risk is different.

This is where many AI review bots disappoint me. They read the patch, generate plausible comments, and call it a review. Sometimes that catches real issues. Sometimes it produces style advice while missing the bug that lives one call up the stack.

## A reviewer that never runs code is guessing

Static review matters, but a reviewer that never sees execution evidence is missing half the story.

For a serious PR, I want the reviewer to know things like:

- did the tests pass?
- which tests failed before the fix?
- did coverage move?
- did a migration run?
- did a browser spec generate a screenshot?
- did a benchmark change?
- did a linter or type checker already report the obvious thing?

This is the same lesson as debugging deterministic CI failures. The source code alone does not tell you everything. The failed log, generated HTML, database state, and test order can tell you what the app actually did.

AI review should not replace CI. It should consume CI.

If the model says, "this may break authentication," that comment is more useful when it can cite the relevant spec result, call path, or missing test. Otherwise it is only a guess with good grammar.

## AI brings its own taste and bias

The danger is not that the model is stupid. The danger is that it is fluent.

An AI reviewer can prefer familiar patterns too strongly. It may suggest extracting a service object because that sounds clean, while missing that the important part is a one-line authorization condition. It may complain that a method is long, but miss that a refactor changes transaction boundaries. It may push generic best practices into code that has a domain-specific constraint.

There is also a training-data taste problem. Models tend to like code that looks like code they have seen often. That does not always mean it fits this system.

This is why I do not want AI review measured by comment count. A bot that writes ten low-value comments is worse than a bot that writes one precise warning. Review fatigue is real. Once developers learn that the bot mostly comments on style, they stop reading it.

## Missing context is where the real bugs hide

Human reviewers carry scar tissue.

They remember that one customer sends malformed CSV. They know that a column looks unused but feeds a report. They know the response shape is weird because an old mobile client still depends on it. They know a path should not be touched just before a release window.

That knowledge rarely appears in the diff.

A better AI reviewer needs more than a patch. It needs a way to retrieve related files, rules, previous decisions, test output, and repository-specific conventions. OpenCodeReview's design is interesting here because it is not only a free-form agent. Its README describes deterministic file selection, file bundling, rule matching, positioning, and reflection modules around the LLM. That matters because the model should not be trusted to improvise the review process from scratch every time.

The model can reason over context. The system around the model should decide which context is safe and relevant to show it.

## Trying OpenCodeReview locally

The simplest way to try Alibaba's tool is as a CLI. You install `ocr`, configure an LLM endpoint, and run it from inside a Git repository.

I would start locally before wiring it into CI. Local mode lets you see the noise level before a bot starts posting comments on every PR.

### Step 1: install the CLI

OpenCodeReview is published as an npm package:

```bash
npm install -g @alibaba-group/open-code-review
```

Check that the command is available:

```bash
ocr version
```

The project requires Git. The README currently says Git 2.41 or newer:

```bash
git --version
```

### Step 2: configure the model

OpenCodeReview can use a built-in provider or a custom LLM endpoint.

The interactive path is:

```bash
ocr config provider
ocr config model
ocr llm test
```

For CI, environment variables are usually safer than writing long-lived credentials into a local config file. The exact endpoint depends on the provider, but the shape looks like this:

```bash
export OCR_LLM_URL="https://<llm-endpoint>"
export OCR_LLM_TOKEN="<api-token>"
export OCR_LLM_MODEL="<model-name>"
export OCR_USE_ANTHROPIC="false"   # true for Anthropic, false for OpenAI-compatible APIs

ocr llm test
```

Do not paste real tokens into scripts, blog posts, or workflow logs. Use repository secrets in CI.

### Step 3: preview what will be reviewed

Before spending tokens, preview the file set.

```bash
cd your-project
ocr review --preview
```

This matters because bare workspace review includes staged, unstaged, and untracked changes. That is convenient when you are working locally, but surprising if your directory has scratch files.

If the preview is too broad, narrow the scope:

```bash
# Review a branch range
ocr review --preview --from main --to feature-branch

# Review one commit
ocr review --preview --commit abc123
```

### Step 4: add background context

This is the part I would not skip.

OpenCodeReview accepts background context. Use it. The model needs to know what kind of change it is reviewing and what risks matter.

```bash
ocr review \
  --audience agent \
  --background "This PR changes the login flow. Focus on session handling, authorization boundaries, test coverage, and backwards compatibility." \
  --from main \
  --to feature-branch
```

Good background is short and concrete:

```text
This PR adds rate limiting around account registration.
Focus on bypasses, shared Rack configuration, test isolation, and user-visible error behaviour.
```

Bad background is vague:

```text
Please review this carefully and find all bugs.
```

The first tells the reviewer what to be afraid of. The second asks the model to pretend it knows the system.

### Step 5: run review on a branch, commit, or workspace

Common local patterns:

```bash
# Review current working copy
ocr review --audience agent --background "Short context here"

# Review a feature branch against main
ocr review --audience agent --background "Short context here" --from main --to feature-branch

# Review a single commit
ocr review --audience agent --background "Short context here" --commit abc123

# Resume an interrupted review
ocr session list
ocr review --from main --to feature-branch --resume <session-id>
```

I prefer `--audience agent` for automation because it keeps the output easier to parse. Human-facing progress UIs are nice in a terminal but annoying when another agent or CI job needs to read the result.

### Step 6: scan full files when the diff is the wrong artifact

Sometimes there is no useful diff. Maybe you are auditing an old directory, reviewing inherited code, or checking a generated file that entered the repo long ago.

That is where full-file scan mode is useful:

```bash
# Scan the whole repository
ocr scan

# Scan one directory
ocr scan --path app/services

# Scan a small set of files
ocr scan --path app/models/user.rb
```

I would not run whole-repo scans casually on a large private codebase. Start with a directory or a small file set. Full-file scanning is more expensive and can expose more context to the model endpoint.

### Step 7: add repository-specific rules

Generic review is okay for the first pass. Serious review needs local rules.

OpenCodeReview supports rule files. A simple rule file can live under:

```text
.opencodereview/rule.json
```

Example:

```json
{
  "rules": [
    {
      "path": "app/controllers/**/*.rb",
      "rule": "Check authorization before data access. Flag actions that read or mutate records without a clear policy check.",
      "merge_system_rule": true
    },
    {
      "path": "db/migrate/*.rb",
      "rule": "Check for unsafe migrations on large tables: table rewrites, long locks, missing backfills, and non-concurrent indexes.",
      "merge_system_rule": true
    },
    {
      "path": "config/**/*.rb",
      "rule": "Check for logging of secrets, overly broad CORS settings, and environment-dependent behaviour that tests may not cover."
    }
  ]
}
```

Then run:

```bash
ocr review --rule .opencodereview/rule.json --from main --to feature-branch
```

You can also check which rule applies to a file:

```bash
ocr rules check app/controllers/accounts_controller.rb
```

This is where AI review starts becoming more useful. The rule file is a way to encode team scar tissue instead of hoping the model guesses it.

## Using OpenCodeReview in GitHub Actions

Once the local signal is good, CI is the next step.

The OpenCodeReview repository includes a GitHub Action. A minimal PR workflow looks like this:

```yaml
name: AI code review

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]

permissions:
  contents: read
  pull-requests: write

jobs:
  ocr:
    runs-on: ubuntu-latest
    steps:
      - name: Run OpenCodeReview
        uses: alibaba/open-code-review@main
        with:
          llm_url: ${{ secrets.OCR_LLM_URL }}
          llm_auth_token: ${{ secrets.OCR_LLM_TOKEN }}
          llm_model: ${{ secrets.OCR_LLM_MODEL }}
          llm_use_anthropic: "false"
          language: English
          background: >-
            Review this pull request for correctness, missing tests,
            security-sensitive data flow, and risky runtime behaviour.
            Prefer fewer high-confidence comments over style nits.
          incremental: "true"
          sticky_summary: "true"
```

A few details are worth calling out.

First, keep permissions narrow. The bot needs to read code and write PR comments. It should not need broad repository write access.

Second, keep model credentials in repository or organization secrets. Do not print them. Do not pass them through command-line examples in logs.

Third, start with `incremental: "true"` and `sticky_summary: "true"`. A sticky summary avoids posting a new wall of text on every push. Incremental mode reduces duplicate inline comments when the PR changes.

Fourth, do not block merges on day one. Let the reviewer run in advisory mode first. Measure whether the comments are useful before turning it into a gate.

## A safer rollout plan

I would introduce AI PR review in stages.

### Stage 1: local-only experiments

Run `ocr review` on a few real PRs after the human review is already done. Compare the output against what people actually found.

Keep a small table:

| PR | Useful findings | False positives | Missed important issues | Notes |
|---|---:|---:|---:|---|
| A | 2 | 4 | 1 | Good on tests, noisy on style |
| B | 0 | 3 | 2 | Missed auth context |

The numbers do not need to be perfect. You are checking whether the tool changes reviewer behaviour in a good way.

### Stage 2: CI summary only

Run it in CI, but post only a summary or artifact. Humans can open the report when they want it.

At this stage I would tune:

- rules;
- background context;
- model choice;
- file filters;
- concurrency;
- comment thresholds.

### Stage 3: inline comments on selected PRs

Enable inline comments for selected repositories or labels. Do not unleash it on everything at once.

Good candidates:

- backend service changes with tests;
- security-sensitive changes with narrow scope;
- migration-heavy PRs;
- refactors where the call path matters.

Bad candidates:

- huge generated diffs;
- formatting-only PRs;
- vendor updates;
- speculative architecture spikes;
- changes containing sensitive customer data or private logs.

### Stage 4: policy for what the bot is allowed to say

The reviewer should separate findings by confidence:

- blocking bug;
- security concern;
- missing test;
- unclear context;
- style/nit.

The first three are useful. The last two should be quiet unless asked.

A noisy AI reviewer trains humans to ignore it.

## What OpenCodeReview improves

OpenCodeReview's interesting idea is not "LLM reads diff." Everyone can do that.

The interesting part is the deterministic scaffolding around the model:

- choose the right files;
- bundle related files;
- match rules to paths;
- use a review-specific toolset;
- improve comment positioning;
- reflect on comment quality;
- support full-file scans when a diff is not enough.

That architecture acknowledges something important: the model should not own the whole review process. The system should constrain the process, and the model should operate inside those constraints.

That matches how I want to use agents in general. Give the model a narrow job. Give the surrounding system the boring guarantees.

## What it still will not solve

Even with a better tool, AI PR review still has limits.

It will miss context that is not in the repo, not in the rules, and not in the prompt.

It may not know that a messy endpoint is kept stable for a mobile client. It may not know that a background job is safe because of an operational runbook. It may not know that the real risk is a deployment sequence, not a code path.

It also does not own the tradeoff. A reviewer can say, "this is risky." A team still has to decide whether that risk is acceptable today.

That is why I want AI review as a first pass, not final authority.

## The review architecture I want

The useful shape is:

```text
PR diff
  + related files
  + repository rules
  + CI results
  + test artifacts
  + code ownership/context
  + human review history
  -> AI first pass
  -> human judgment
```

The AI should catch boring mistakes, point to suspicious changes, ask for missing tests, and summarize risk areas. It should cite evidence. It should say when it is unsure. It should not flood the PR with generic advice.

The human still owns the hard part:

- product intent;
- operational timing;
- architecture direction;
- acceptable risk;
- whether the ugly code is ugly for a reason.

I still want AI in the review loop. I just do not want to pretend the model reviewed the system because it read the patch.

The dangerous AI reviewer sounds like it understood the whole change when it only saw the diff.

The useful AI reviewer is more modest: it reads the change, gathers nearby context, checks the boring things, and leaves the final judgment to someone who has to live with the result.
