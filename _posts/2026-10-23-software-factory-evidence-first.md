---
layout: post
title: "Designing a software factory for verifiable delivery"
date: 2026-10-23 07:00:00 +0000
author: "Joey Wang"
description: "A software factory design with durable evidence, risk-based reviews and human approval, tested first on whether it stops safely rather than how fast it runs."
tags: [ai, agents, hermes, automation, testing]
categories: [AI, Engineering]
---

<div class="audio-summary">
  <p><strong>Audio summary: a short English summary, generated with local text-to-speech.</strong></p>
  <audio controls preload="metadata">
    <source src="/assets/audio/2026-10-23-software-factory-evidence-first-summary.ogg" type="audio/ogg">
    Your browser does not support the audio element.
  </audio>
</div>

[中文版](/posts/software-factory-evidence-first-zh/)

In [my earlier design for a one-person company](/posts/ai-native-one-person-company-operating-system/), I kept coming back to coordination. Customer feedback, product decisions, code, operational failures and the next piece of work all compete for the same person's attention.

The software factory covers a more specific part of that problem: once something is worth doing, how does it become a software change that someone can inspect, take over and, if necessary, roll back?

My starting point is practical. Getting a coding agent to change code is not especially difficult. The harder parts are letting the next execution pick up where the previous one stopped, giving reviewers the original request rather than just the implementer's summary, and stopping failures in the right place instead of pushing the process forward with more prompts.

This article describes a design I am still working through. It is not an unattended delivery platform that I have validated end to end. The risk tiers, rework limits and acceptance rules below all need testing in a small pilot.

## A software factory can start with a small loop

Matt Pocock's [Dictionary of AI Coding](https://github.com/mattpocock/dictionary-of-ai-coding#software-factory) gives software factory a simple definition: automation that starts agent sessions in response to triggers.

My reading of that definition is that a scheduled job handling one kind of small maintenance task and leaving a PR for human review already qualifies. A factory does not require people to leave every decision to automation.

That differs from a [dark factory](https://github.com/mattpocock/dictionary-of-ai-coding#dark-factory). In the same dictionary, a dark factory is an area of a codebase where humans no longer read the changes the factory produces. On that reading, unattended execution overnight followed by human PR review in the morning is still a human-reviewed software factory.

The first model is the one I want to test. Automation prepares and carries out some of the work. People retain responsibility for product choices, consequential approvals and releases.

## Separate a request from an execution

The word "task" is easy to overload. It can mean a ticket, a reusable kind of work such as implementation or review, or the particular attempt an agent is making right now.

The distinctions below are my adaptation of [Matt Pocock's draft software-factory vocabulary](https://github.com/mattpocock/skills/pull/1316), not a verbatim glossary. I use them to express my own delivery constraints.

- **Work item / ticket**: a specific request that preserves its source, goal and acceptance criteria.
- **Task**: a reusable kind of work, such as investigation, implementation, review or rework.
- **Run**: one attempt to execute a Task, with a clear beginning and end.
- **Trigger**: an event that starts a Run, such as a ticket becoming ready, a failed review or a human supplying missing information.
- **Runner**: the execution environment, which might be a local process, a worker node or a disposable cloud machine.

A single ticket can therefore go through several Runs for investigation, implementation, review and rework. Its durable state should not live only in one of those conversations.

When a human needs to answer a question, the Run does not have to wait indefinitely. It should record the question and available evidence, end execution, and leave the ticket in a state such as "needs clarification" or "needs decision". A later event starts a fresh Run after the human updates it.

Recovery then does not depend on keeping a particular session alive.

## The control plane coordinates work; existing systems retain the facts

I do not want to start by building a new platform that does everything.

Git already records code history. CI records check results. An issue tracker holds requests and ownership. Observability systems report operational problems. Copying all of that data into another system can easily produce several contradictory versions of the "latest state".

In this design, Hermes is the coordination and approval entry point that connects the existing systems:

```text
Problem sources / customer feedback / operational signals
                          ↓
          Ticket: request, scope, acceptance criteria
                          ↓
          Control plane: routing, permissions, budget
                          ↓
          Isolated execution → candidate code
                          ↓
          Automated checks → independent review
                          ↓
          Human decisions and release authorization
                          ↓
          Normal release process → outcome verification
```

The ticket explains what needs solving. Git identifies the code. CI records which checks ran against a particular version. Company OS holds reviewed designs and decisions, while the personal knowledge system keeps its own privacy boundary.

The control plane records the relationships between these objects and the execution history. It does not declare facts on their behalf. An agent saying "the tests passed" still needs the corresponding command, exit status and results. Saying "it has been deployed" needs evidence from the deployment system and the running environment.

A new component is worth adding only when a necessary capability is genuinely missing between the existing systems.

## Hand over evidence, not just a summary

I want a ticket to connect the answers to these questions:

```text
request:  Why are we doing this? What outcome do we want?
scope:    What may change? What is explicitly out of scope?
plan:     How will we implement, check and recover?
decision: What consequential trade-offs exist, and who decides?
change:   What actually changed? What did execution return?
audit:    Does this candidate satisfy the original request?
debt:     Which remaining risks have been explicitly accepted?
```

This does not mean creating seven files for every change. For a small documentation update, the request can stay in the ticket, with the change and checks in the PR. Interface changes, data semantics and important business rules call for a fuller record.

These records should link through a stable ticket ID and candidate commit SHA, rather than repeat the same description in several places.

Review findings, in particular, must identify the version they apply to. If code changes after approval, the old review cannot automatically authorize the new candidate. During the pilot, I would require a fresh review for every new SHA. Any later policy for carrying a review across a content-identical rebase would need explicit verification rules.

Failed results need to survive too. A passing final test run should not erase earlier failures, their causes or the changes made to address them.

## Risk determines review requirements, not which model seems smarter

I treat risk classification, executor selection and acceptance authority as separate decisions.

A model name can influence who performs the work. It cannot expand permissions or replace acceptance checks.

The current design organizes checks into four risk tiers:

- **L0**: documentation or formatting only, with scope, link and format checks; no sensitive policy changes or executable behavior.
- **L1**: localized, reversible code changes, with tests mapped to acceptance criteria and an independent review Run that did not implement the candidate.
- **L2**: changes across components or interfaces, changes to data semantics, or dependency and configuration changes with meaningful impact. These need impact analysis, broader regression evidence and a recovery plan. Product or data-contract trade-offs go to a human decision-maker.
- **L3**: security, permissions, privacy, production or customer data, and destructive or hard-to-reverse operations. These need explicit human authorization, review by the appropriate owner and post-action read-back verification.

The work type supplies a default checklist; risk flags can only raise the requirements. A "chore" label is not evidence of low risk, and calling something a "bug fix" does not make an authentication change harmless. Unknown general risk defaults to at least L2. Unknown data classification or any production touch defaults to L3.

Classification also continues during execution. Discovering a need to expand scope, add a dependency, change test expectations, skip tests, update snapshots or increase timeouts should raise a scope question and trigger reassessment. The implementer should not make those decisions unilaterally just to finish the job.

The factory's own controls are protected code too. Changes to triggers, review rules or permission boundaries are at least L2. Weakening a critical stopping mechanism makes them L3.

## Independent review needs an explicit candidate

Independent review cannot mean asking a model to reread its own summary.

I want the reviewer to receive the original request, acceptance criteria, base SHA, candidate SHA, complete diff and actual check results. The review Run does not implement the change and cannot approve its own edits while repairing the code.

Switching models does not automatically create independence. If a reviewer sees only the implementer's selected account of the work, it can inherit the same faulty assumptions.

Likewise, a review state in a workflow interface does not prove that review is an enforced gate. State transitions and permission controls need testing to establish that an executor cannot bypass a required review and declare completion. Hermes's [Kanban documentation](https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban) and [worker lanes documentation](https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban-worker-lanes) describe mechanisms for cards, run history, handoffs and completion contracts, but their configuration and execution semantics still need checking in the version used for the pilot.

Workspace isolation needs a precise definition as well. A [Git worktree](https://git-scm.com/docs/git-worktree) can keep two executors' file edits apart. It does not restrict a process from reading host files or credentials, or accessing the network. A security sandbox requires separate operating-system-level controls over files, network access, credentials and resources.

Human approval must also be a verifiable event from an identity that automation cannot impersonate. An agent filling in an `approved: true` field does not count as human authorization. During the pilot, humans review every L2/L3 change and spot-check lower-risk changes. L3 recovery or rollback paths also need actual testing.

## Route rework to the step that can resolve it

After a workflow fails, the easiest implementation is often to restart the entire agent. That can repeat investigations into facts already known, or treat a permissions failure as a code problem.

I want each piece of feedback to include at least the problem type, expected and actual behavior, evidence, severity, owner and next action.

Missing acceptance criteria should go back to the request owner. Conflicting product semantics should go to the decision-maker. A test failure should return a minimal reproduction, the failing command and its results to the implementer. An unavailable external service calls for a pause and recorded recovery conditions, not more code changes to use up the retry budget.

For findings from a code review, the shortest route is usually:

```text
Implementation → checks → review
                            ↓ finding
                       Targeted rework
                            ↓
              New candidate → fresh checks and review
```

The pilot provisionally allows at most two consecutive automated rework Runs per trigger chain before a human reassesses the scope or approach. Two is an operating constraint to test, not a universally optimal number. Infrastructure retry counts should not be assumed to measure review rework either.

An unmet acceptance criterion cannot be renamed "technical debt" so the ticket can close. Debt covers only explicitly accepted remaining risks with an owner and conditions for revisiting them.

## Assume triggers will repeat and execution will stop

Every new trigger source needs answers to a few specific questions:

Who starts execution? Which systems may it read and write? What does completion trigger next? Where does a human re-enter? How do duplicate events avoid creating duplicate work?

An external event ID, for example, can be an idempotency key when creating a ticket or card. That does not make every subsequent operation idempotent. Branch creation, PR creation and writes to external records each need their own deduplication and read-back rules.

If a Runner stops, whoever takes over should at least be able to recover the original request, current candidate, completed external actions, available evidence and blocking reason from durable records. If it is unclear whether a write succeeded, query the target state before writing again.

That is why I treat a Runner as replaceable execution capacity. Even when the machine persists, recovery should not depend on its conversation context or the only local copy of a file.

## The first pilot should test whether the system stops

I do not plan to begin by connecting every alert and repository, then running several agents in parallel. For a small team, generating changes can easily outpace the capacity to review them.

The first step should be one manually selected, non-sensitive, low-risk piece of work with a clear scope. Fix the acceptance criteria before execution. Confirm the implementer's and reviewer's actual identities, permissions and workspaces. Then walk through implementation, checks, review and a human decision. Merge and deployment remain separately authorized actions.

Next, deliberately introduce failures in a disposable environment. Add a known defect and see whether review catches it. Fail a required check and see whether the workflow refuses completion. Change the candidate after review and see whether the old approval becomes invalid. Deliver the same event twice and look for duplicate work. Omit necessary information and see whether execution stops and asks a precise question.

Passing those tests would show only that the corresponding control paths worked under the test conditions. It would not establish that the whole factory is reliable, much less that it has saved money.

Only then would I move to a small number of real tasks, one at a time, recording successes, failures, blockers and abandoned attempts. I would track the total human effort spent prompting, reviewing, repairing and maintaining the system, alongside tool costs, missed defects and final outcomes. Without a comparable manual baseline, I would not claim a particular time saving.

I hope this design will reduce lost context, repeated investigation and unproductive rework. Whether it is worth building further depends on the total cost of an accepted result, and whether that result solves a problem worth solving.

Until I have that evidence, I would rather work toward a delivery loop with limited throughput and tested stopping behavior than automatically send more work into the queue.

## References

1. [Matt Pocock: Dictionary of AI Coding: Software factory and Dark factory](https://github.com/mattpocock/dictionary-of-ai-coding#software-factory)
2. [Matt Pocock: Draft software-factory vocabulary, PR #1316](https://github.com/mattpocock/skills/pull/1316). When I wrote this, the PR was open and marked Draft. It supplies a design vocabulary, not an executable pipeline.
3. [Hermes Agent: Kanban](https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban)
4. [Hermes Agent: Kanban worker lanes](https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban-worker-lanes)
5. [Git documentation: git-worktree](https://git-scm.com/docs/git-worktree): explains multiple working trees; workspace separation is not a security sandbox.

*This article develops the delivery portion of [my earlier Company OS design](/posts/ai-native-one-person-company-operating-system/). The risk tiers, evidence structure and pilot constraints are proposed working rules. They are neither complete guarantees supplied by the projects above nor validated industry standards.*
