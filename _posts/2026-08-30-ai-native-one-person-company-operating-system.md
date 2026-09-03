---
layout: post
title: "The One-Person Company Is a Coordination Problem"
description: "I am exploring how a one-person company could use agents, observability, project tracking, and market intelligence without turning automation into an ungoverned second company."
date: 2026-08-30 12:00:00 +0000
author: "Joey Wang"
tags: [ai-agents, one-person-company, hermes, software-engineering, product-management, market-intelligence]
categories: [AI, Engineering]
---

<audio controls preload="metadata" src="/assets/audio/ai-native-one-person-company-operating-system-summary.ogg">
  Your browser does not support the audio element.
</audio>

# The One-Person Company Is a Coordination Problem

I did not start with the idea of building an AI company. I started with a more ordinary problem: too many small operational loops were competing for the same limited attention.

I have been thinking about a slightly unusual company structure.

Not a startup with a large engineering team and an AI assistant on the side. A one-person company in which the founder can move between product, development, project management, customer conversations, and market research without losing the thread between them.

The attraction is obvious. A capable language model can help write code, investigate an error, turn an idea into a product brief, summarize competitors, and prepare the next decision. It can fill some gaps that would traditionally require several specialists.

But “AI can do many jobs” is not yet an operating model.

The harder question is how to connect those jobs safely. If Sentry sees an error, can an agent investigate it? If a market signal suggests a new feature, how does that become a real product decision? If an agent changes code, who verifies it? If a cloud worker disappears, what state is lost?

I am treating this as a design and learning project, not as a claim that one person can automatically replace an entire company. None of this is a finished product yet. It is a design hypothesis assembled from existing tools, small experiments, and a set of constraints I want to test.

## The problem is coordination, not just coding

A small company usually has several different loops running at once:

```text
customer problem
      ↓
market signal → product decision → feature work → release
      ↑                                  ↓
customer feedback ← support ← observability
```

In a larger organization, these loops are distributed across people and systems. Product managers maintain the roadmap. Developers work from issues and pull requests. Sentry and other observability tools report production problems. Marketing and sales bring back market information.

In a one-person company, all of these loops eventually return to one person.

The bottleneck is not necessarily typing code. It is remembering what matters, deciding what to do next, switching contexts, and keeping the evidence connected to the decision.

That is where an AI-native operating system could help.

## Four kinds of digital work

My current model has four related but distinct responsibilities.

### 1. Bugs and operational signals

Sentry should remain the source of truth for runtime errors and performance problems. An agent could:

1. group and summarize a new error;
2. identify likely affected code;
3. compare it with previous incidents;
4. prepare a reproduction or test;
5. propose a fix in an isolated worktree;
6. run the project's checks;
7. open a pull request for review.

The important word is **propose**.

A Sentry event is evidence that something happened. It is not permission to edit production code, deploy a change, or declare an incident resolved. An AI-generated patch still needs tests, diff inspection, review, and a rollback path.

The first useful experiment is therefore not “let the agent fix every error”. It is a small Sentry-to-pull-request workflow with a narrow repository scope and a measurable success criterion.

### 2. Features and product work

Features need a different system from errors. A bug report can start with a stack trace. A feature starts with a customer problem, a market observation, or a strategic choice.

Jira, Redmine, or another issue tracker should remain the source of truth for:

- product requirements;
- acceptance criteria;
- dependencies;
- milestones;
- ownership;
- status and delivery history.

An agent can help turn a rough idea into a smaller set of tasks. It can identify missing acceptance criteria, find related work, draft release notes, and flag scope expansion. It should not quietly turn every interesting market signal into a feature.

For a very small company, Jira may be more process than is necessary. Redmine offers more control if I am willing to operate it. A simpler hosted issue tracker may be the better starting point. The correct choice depends less on the feature list than on whether I will actually maintain the workflow.

### 3. Project management

The AI project manager is not a virtual person who “owns delivery”. It is a coordinator that keeps project state visible.

A useful project-management agent could answer:

- What is blocked?
- Which task has no acceptance criteria?
- What changed since the last review?
- Which milestone is at risk?
- Are there more open tasks than the current capacity allows?
- What is the smallest next deliverable?

It could prepare a daily or weekly report from the issue tracker, Git, pull requests, CI, and Sentry. That is valuable because reporting is repetitive. The final decision about priority, trade-offs, and commitments still belongs to the founder.

A useful report might be deliberately boring:

```text
Weekly project report

Progress:
- 2 tasks completed
- 1 pull request awaiting review

Blocked:
- Sentry issue has no reproducible fixture

Risk:
- The next milestone contains more work than the current weekly capacity

Recommendation:
- Split the export feature and defer the admin UI
```

The point is not to produce an impressive narrative. It is to compress project
state into a decision that I can inspect.

### 4. Market intelligence

Market tracking is a separate loop again. It should collect and compare:

- competitor product and pricing changes;
- customer language and repeated pain;
- industry announcements;
- relevant technical changes;
- distribution and partnership signals;
- evidence that a problem is urgent enough to pay for.

A market agent should produce a small, cited digest rather than an endless stream of links. Every item needs a source, date, confidence, and an explanation of why it may matter.

A trend is not validation. A competitor announcement is not proof of demand. A model's summary is not primary evidence.

The business test is equally important: the system is useful only if it improves
validated outcomes, such as reaching a useful product decision sooner, reducing
unproductive development, finding customer pain earlier, or delivering a first
paid version with less coordination overhead. More summaries, tickets, and agent
traces are not outcomes by themselves.

## A layered architecture

The current design looks like this:

```text
                         founder
                            │
                   decisions and approvals
                            │
                         Hermes
              personal control plane and router
          ┌─────────────────┼─────────────────┐
          │                 │                 │
      Sentry            issue tracker       market sources
          │                 │                 │
          └────────────── agents ────────────┘
                            │
                 Git, CI, worktrees, reports
                            │
                   cloud or local workers
```

The systems should not all become one database.

- Sentry owns runtime observations.
- The issue tracker owns product and delivery state.
- Git and CI own code and verification evidence.
- A market-watch record owns collected external signals.
- Company OS owns company strategy, sales, and operations.
- Life OS owns durable personal decisions, learning, and reflections.
- Hermes coordinates the workflow and applies approval policy.

This separation is important. An agent should retrieve the relevant context without silently becoming the owner of every piece of state.

## Where the proposed tools fit

I am considering four broad categories of tools.

### Google AI Studio

AI Studio is useful for trying models, prompts, generated applications, and API ideas quickly. It is a good laboratory and prototyping surface.

I would not make it the company's control plane. A prototype interface is not the same thing as durable workflow state, identity management, audit history, repository permissions, or release governance.

### ChatGPT Workspace

A shared ChatGPT workspace could be a useful human-facing layer for drafting product requirements, reviewing market notes, and asking cross-functional questions.

It should not become the authoritative system for code, incidents, releases, or customer records. Those need systems with explicit state, access controls, and history.

### Hermes and ZeroClaw

Hermes is the natural candidate for my primary personal control plane because it already connects memory, skills, document retrieval, scheduled workflows, model routing, messaging, and delegated coding work.

ZeroClaw is interesting as a smaller, more portable worker or experimental runtime. I do not want to create two unrestricted control planes that both believe they own the same memory, credentials, and automations.

The division should be explicit: one orchestrator, specialized workers, narrow permissions.

### Spot VM

A Spot VM can provide inexpensive, interruptible capacity for jobs that can be retried or discarded. It is a reasonable place for an ephemeral coding worker, a batch analysis task, or a disposable test environment.

It is not a good place for the only copy of company state. Important state must live in durable storage, and a worker must be able to restart without guessing what happened before the interruption.

The previous estimates I saw for monthly Spot VM cost should be treated as planning assumptions, not promises. Region, machine type, disks, network traffic, quotas, and interruption behavior all affect the real cost.

My current default is therefore deliberately small: Hermes as the orchestrator,
Sentry and GitHub as integration sources, an existing issue tracker for product
state, and a Spot worker only for jobs that are demonstrably interruptible. I do
not want to build the full platform before proving that one workflow saves time.

## Why not buy the whole thing?

The obvious alternative is to buy a collection of SaaS products and avoid building
anything. That is probably the right answer for much of the system.

Existing services are better at durable records, authentication, notifications,
and collaboration than a one-person custom platform would be. The reason to add
a control layer is narrower: connect the systems I already use, route work to the
right model or worker, enforce approval boundaries, and produce a useful report
without copying all state into a second database.

Self-hosting becomes worthwhile only when it solves a demonstrated problem:
privacy, integration control, cost at a known workload, or a workflow that the
hosted products cannot express. Otherwise, operating another dashboard is just
another coordination loop.

## The control plane needs authority levels

Not every action should have the same approval requirement.

### Low risk

- summarize a document;
- search notes;
- classify an issue;
- draft a product brief;
- prepare a project report;
- inspect a repository without changing it.

### Medium risk

- edit files in an isolated worktree;
- create a pull request;
- update a private task;
- prepare a customer reply;
- generate a market digest.

### High risk

- deploy to production;
- modify infrastructure;
- retrieve, display, copy, or transfer credentials;
- send sensitive external messages;
- change VPN, SSH, or gateway continuity;
- delete durable data;
- make financial or legal commitments.

The model should not be asked to decide whether its own action is safe. The workflow should encode the boundary, and the human should remain at the sensitive gates.

## What I would build first

I do not want to start by building a complete multi-tenant enterprise platform. That would be an impressive way to avoid learning whether the workflow is useful.

The first vertical slice should be:

```text
Sentry event
   → sanitized issue context
   → bounded agent investigation
   → isolated worktree
   → proposed fix and test
   → independent verification
   → pull request
   → human review
```

I would measure:

- time from event to useful diagnosis;
- percentage of issues where the agent finds the right area;
- percentage of proposed patches that pass tests;
- review and rework time;
- false fixes and regressions;
- model cost per useful pull request;
- how often a human has to intervene.

If this loop does not work on a small, synthetic or low-risk fixture, adding more dashboards and more agents will not help.

## A possible article series

This is the beginning of a series rather than a finished architecture. Possible follow-up articles include:

1. **Can Sentry safely trigger an AI coding-agent workflow?**
2. **Why an issue tracker should remain the source of truth for features.**
3. **Hermes, Pi, and a custom loop: which layer should I build?**
4. **Memory and skills in a multi-user engineering system.**
5. **Model gateways, shared quotas, and the cost of AI coordination.**
6. **Running interruptible cloud workers without losing state.**
7. **What an AI project manager should report—and what it should never decide.**
8. **Market intelligence without turning the company into a link-collection machine.**

Each article should be based on an actual experiment, repository state, source-backed comparison, or failure. I would rather publish a small workflow that worked and explain its limits than publish a grand diagram that has never been exercised.

## The real goal

The goal is not to pretend that one person has become ten people.

The goal is to reduce the cost of moving between important roles without losing judgment. A developer should be able to investigate a market signal. A founder should be able to understand an operational incident. A project manager should be able to see what is actually blocked. An agent should be able to do the repetitive preparation work while leaving accountability visible.

That requires more than a strong model. It requires clear sources of truth, narrow permissions, durable state, independent verification, and a willingness to stop automation when the evidence is weak.

For now, this is a plan. The next step is not to automate the whole company. It is to prove one bounded loop, measure it honestly, and let the next article follow from what actually happened.

## Further reading

- [Hermes Agent](https://hermes-agent.nousresearch.com/docs/)
- [Google AI Studio](https://ai.google.dev/aistudio)
- [Sentry Seer Autofix](https://docs.sentry.io/product/ai-in-sentry/seer/autofix/)
- [Jira features](https://www.atlassian.com/software/jira/features)
- [Redmine](https://www.redmine.org/)
- [Google Cloud Spot VMs](https://docs.cloud.google.com/compute/docs/instances/spot)
- [Hermes, OpenClaw, NanoClaw, ZeroClaw, and IronClaw](https://joeywang.github.io/posts/hermes-openclaw-nanoclaw-zeroclaw-ironclaw/)
- [Orchestrating Hermes with Local Gemma](https://joeywang.github.io/posts/orchestrating-hermes-local-gemma/)
