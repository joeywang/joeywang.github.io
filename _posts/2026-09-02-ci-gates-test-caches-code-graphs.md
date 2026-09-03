---
layout: post
title: "CI Gates, Test Result Caches, and the Code Graph That Might Tell Us What to Test"
description: "What I learned from splitting CI by risk, caching exact test results, and exploring AI and code graphs for safer test selection."
date: 2026-09-02 17:00:00 +0000
author: "Joey Wang"
tags: [ci, testing, ruby-on-rails, github-actions, ai, coding-agents, code-graph, developer-tools]
categories: [Engineering, AI]
---

<audio controls preload="metadata" src="/assets/audio/ci-gates-test-caches-code-graphs-summary.ogg">
  Your browser does not support the audio element.
</audio>

A green CI run can still leave me with an uncomfortable question:

> Did we run the right tests?

The opposite problem is easier to recognise. A pull request runs every test, every time, even when the change is a README edit or a small isolated helper. The feedback loop gets slower, the bill gets larger, and eventually somebody starts looking for ways around it.

That is how a safety system becomes a delivery tax.

Recently I applied a risk-based CI gate to Turtle, following improvements I had already made in REX. The change was deliberately modest. It did not pretend that a script could understand the entire architecture. It classified changes into test levels, kept RuboCop independent, and used the full suite for high-risk paths and releases.

The more interesting part came afterwards: caching test-result context and asking whether a code graph or an AI agent could help us decide what deserves testing in the first place.

## The old choice: slow or unsafe

The usual CI conversation is presented as a binary choice:

```text
run everything every time
  -> safe but slow

run only what looks relevant
  -> fast but risky
```

Neither is good enough.

Running everything is a reasonable baseline, especially for a small repository. But it hides the fact that not all changes have the same risk. A documentation-only change does not need the same RSpec scope as a database migration, dependency lockfile change, or production release.

Running a guessed subset is more dangerous. File paths are not the same thing as runtime behaviour. A change in a serializer may affect an API response. A configuration change may alter boot behaviour. A seemingly local model callback may be used by a background job, an admin screen, and a mobile endpoint.

The useful goal is not “run fewer tests.” It is:

> Make the smallest test decision that is still justified by evidence, and make the decision visible.

## A gate before the test job

The Turtle workflow now has a small `ci_gate` job before RSpec. It classifies the pull request and publishes the decision in the GitHub Actions summary.

The levels are intentionally understandable:

| Level | Category | Typical coverage |
| --- | --- | --- |
| L0 | Static-only | RuboCop and other static checks; documentation-only work can skip RSpec |
| L1 | Affected | Fast library, model, and helper specs |
| L2 | Smoke | Fast specs plus request, controller, and view specs |
| L3 | Full | The complete parallel RSpec suite |

The classifier considers the changed paths, the branch name, and optional labels such as `risk:bugfix` or `risk:feat`. High-risk paths—dependencies, database changes, Dockerfiles, workflow files, and test boot configuration—escalate the level. A label can raise the required level, but it cannot lower a level implied by the changed files.

That last rule matters. A label is a useful human signal. It is not permission to bypass evidence.

The release path always selects L3. Production is where optimism becomes an incident, so the test decision should be boring and conservative there.

RuboCop remains a separate required job. The test classifier does not decide whether Ruby style and static checks should run. This is important because a fast test path should not accidentally become a fast-everything path.

## What the gate does not claim

The first version is not a perfect test-impact analysis system.

For example, L1 currently runs a broad group of fast specs rather than calculating the exact affected examples. L2 adds request, controller, and view coverage. This is useful prioritisation, but it is still a policy-based approximation.

That is a feature, not an embarrassment.

A transparent approximation is easier to review than a mysterious “AI selected 14 tests” result. The workflow tells us which level was selected and why. If the policy is wrong, we can improve the policy without pretending that the existing result was mathematically precise.

A good first gate should make risk visible before it tries to automate every decision.

## Caching test results without caching confidence

The second improvement in REX was to cache test-result context. The important distinction is that we do not treat an old green result as proof that a new commit is safe.

The cache key includes the things that can change what a test means:

```text
repository
commit and ref
suite and test level
exact command
Ruby / Node / pnpm environment
lockfiles and test configuration
```

The key is derived from a canonical JSON description and a SHA-256 digest. If the environment or test command changes, the key changes too.

This is the shape of the context rather than just a directory called `test-cache`:

```json
{
  "repository": "...",
  "sha": "...",
  "suite": "rspec",
  "level": "full",
  "command": "bundle exec rails parallel:spec",
  "ruby": "...",
  "node": "...",
  "files": {
    "Gemfile.lock": "...",
    "pnpm-lock.yaml": "...",
    "config/webpacker.yml": "..."
  }
}
```

The exact commit is part of the identity. That means the cache is not pretending that a result for one source revision is a current result for another revision.

So what is it useful for?

One use is diagnostics. When a replacement run starts, it can find the previous failed RSpec result for the same branch and environment, then run the previously failed examples first. This gives fast feedback about a likely regression while the required suite continues to provide the real gate.

The ordering looks like this:

```text
new commit
  -> calculate exact test context
  -> restore matching failure evidence
  -> run previous failed examples first
  -> run the required suite
  -> upload current results
```

The failed-example lane is not a replacement for the required suite. It is a short feedback lane. A cached failure is evidence about where to look first, not a verdict about the new code.

That distinction is easy to lose when a CI optimisation is described as “test caching.” We should cache evidence and reproducible context, not confidence.

GitHub's [dependency caching documentation](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching) makes a related point: cache keys should change when the inputs that produce the cached output change, and workflows can use the cache-hit result to decide whether work can be skipped. For test results, the inputs need to be much richer than one lockfile hash.

## Where a code graph can help

The next question is harder:

> How do we know which tests are connected to the changed code?

This is where code-intelligence and graph tools become interesting. A graph can represent relationships that a directory-based classifier cannot see:

```text
changed controller
  -> route
  -> authorization policy
  -> service object
  -> model callback
  -> background job
  -> request and system specs
```

A useful system could use those relationships to propose a test set. It might also identify a path that crosses an application boundary, such as a Rails endpoint calling another service or emitting a job consumed elsewhere.

For my own setup, [GitNexus](https://github.com/abhigyanpatwari/GitNexus) is an interesting candidate because it exposes dependency, call-chain, execution-flow, and impact-analysis views through a local-first code knowledge graph. The important word is *candidate*. Its output still needs to be checked against the actual Rails conventions and test suite.

[CodeQL](https://codeql.github.com/docs/writing-codeql-queries/about-data-flow-analysis/) offers a different model. It is designed for querying code as data and analysing data-flow paths. That is particularly valuable for security and source-to-sink questions, although it is not a drop-in RSpec test selector for a Rails application.

Commercial test-impact systems such as [Launchable](https://help.launchableinc.com/) take another approach: combine repository changes with historical test behaviour and use predictive selection to choose tests. That can be powerful, but it introduces a new dependency on historical data quality. A test that has never failed may still be important. A flaky or under-specified test can distort the model.

I would separate the possible tools into three layers:

```text
static graph facts
  -> symbols, routes, calls, imports, ownership

historical evidence
  -> test duration, failures, changed files, flaky examples

AI interpretation
  -> explain the likely blast radius and recommend coverage
```

The first layer should be as deterministic as possible. The second should be measured rather than invented. The third can help us reason, but should show its evidence and uncertainty.

## A safer AI-assisted test decision

I would not begin with an agent that is allowed to skip tests. I would begin with an agent that produces a reviewable proposal:

```text
Inputs:
  diff, changed symbols, routes, graph paths, test history

Output:
  selected test categories
  likely affected tests
  high-risk paths not covered
  reasons and confidence
  tests that still must run unconditionally
```

For example:

```text
Changed: Api::CoursesController#update

Graph evidence:
  route -> controller -> authorization -> Course#update
  controller enqueues CourseIndexJob

Recommended:
  request specs for courses
  authorization specs
  CourseIndexJob specs
  one full smoke path

Mandatory:
  RuboCop
  dependency/security checks
  release-level full suite

Confidence:
  medium — dynamic dispatch and shared concerns are not fully resolved
```

The agent is useful because it gathers and explains relationships. It is not the authority that decides whether production is safe.

That authority should remain in explicit CI policy, source-backed tests, and human-reviewed changes to the policy itself.

## The graph can be wrong

There are several reasons not to overtrust this approach:

- Ruby metaprogramming can hide call relationships.
- Rails conventions can connect code without an obvious direct call.
- Dynamic routes and serializers may not be resolved completely.
- Tests can be badly named or cover less than their file path suggests.
- Historical failures can reflect infrastructure rather than application behaviour.
- A generated explanation can sound more certain than the underlying graph.

This is why I like the idea of evidence layers. The system should distinguish a parsed route from an inferred relationship, and an observed test failure from a model prediction.

The source code and the test results remain authoritative. The graph is an index. The AI explanation is a navigation and reasoning layer.

## What I would implement next

The next practical step is not a full autonomous test selector. It is a report-only mode.

For each pull request:

1. Parse the diff and identify changed symbols.
2. Query the code graph for callers, routes, jobs, and dependencies.
3. Look up recent test history and failed examples.
4. Produce a proposed test set and a confidence score.
5. Compare the proposal with the policy-selected level.
6. Run the stricter of the two decisions.
7. Store the proposal and outcome for later review.

After enough runs, we can measure whether the recommendations are useful:

- Did the proposed tests catch failures earlier?
- How often did the graph miss a necessary test?
- How much time did the prioritised path save?
- Did the full suite catch failures that the proposal missed?
- Did the additional complexity make CI harder to understand?

Only after that evidence exists would I consider allowing a tool to reduce required coverage for a narrow class of changes. Even then, releases and high-risk paths should remain conservative.

## The principle

The best CI system is not the one with the cleverest test selector. It is the one that makes a safe decision quickly, explains why it made that decision, and leaves enough evidence to improve the next decision.

Risk-based gates give us a policy.

Exact-context caches give us reproducible evidence and faster failure feedback.

Code graphs give us a better map of what a change might affect.

AI can help interpret that map, especially when the architecture is difficult to hold in one person's head. But it should not turn an uncertain guess into a green checkmark.

The useful progression is:

```text
full suite baseline
  -> explicit risk policy
  -> exact-context evidence cache
  -> graph-assisted recommendations
  -> measured, reviewable automation
```

That is slower than promising magic and much faster than debugging a production regression caused by a test suite that quietly stopped looking in the right place.
