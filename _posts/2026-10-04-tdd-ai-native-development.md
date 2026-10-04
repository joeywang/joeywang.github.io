---
layout: post
title: "Do We Still Need TDD When AI Writes the Code?"
description: "AI can produce code quickly. Tests, design, and human review still determine whether that code is worth keeping."
date: 2026-10-04 12:00:00 +0000
author: "Joey Wang"
tags: [ai, tdd, testing, software-engineering, claude, codex]
categories: [Engineering, AI]
---

Claude and Codex can write a surprising amount of code from a short description. They can scaffold a feature, add a test, run the suite, and keep editing until the checks pass.

That changes the economics of implementation. It does not answer the question I care about: how do I know the change is correct?

I don't think AI makes test-driven development obsolete. I think it makes the discipline behind TDD more useful, while making a rigid, ceremony-heavy version of it less appealing. The point is not to type every test before every line of code. The point is to make the expected behaviour explicit, get fast evidence when it changes, and keep a person responsible for deciding what the evidence means.

## Passing tests are not proof of the right behaviour

An AI coding agent can write both an implementation and its tests. That is convenient, but it creates a weak spot: the agent may misunderstand the requirement in both places. The code and test can agree with each other and still be wrong for the user.

A green suite answers a limited question: did the checks we ran pass? It does not tell us whether we chose the right checks, whether the requirement was complete, or whether a subtle change in behaviour is acceptable.

This is not an argument against generated tests. They are often a useful first pass. It is a reason to review tests as code, especially at the boundaries that carry business meaning: permissions, billing, learner progress, data retention, and integrations. Those tests should express a rule someone can explain, not merely mirror the implementation the agent just produced.

## Keep the useful part of TDD

TDD is often reduced to a strict sequence: write a failing test, implement the smallest change, refactor. That cycle can work very well, particularly when the expected behaviour is clear and a fast test gives useful feedback.

With an AI agent, the cycle can happen faster, but the important question remains: who chose the example and judged the result? I want the human to own the acceptance criteria and the edge cases. The agent can help turn them into tests, suggest missing cases, and implement the behaviour. Then the human reviews whether the tests actually capture the intent.

For a small, well-understood change, I might ask the agent to write the test first and show me the failure before implementing. For a broad refactor, I may first ask it to map the behaviour and existing coverage, then make a narrow change behind the current tests. Different tasks need different sequences. In both cases, the tests should constrain the work rather than merely decorate it afterwards.

## Code quality needs layers

No single test command can carry the whole burden. I think about quality as a set of layers, each catching a different class of mistake:

```text
clear task and acceptance criteria
             ↓
small implementation with a human-owned scope
             ↓
unit and integration tests for behaviour
             ↓
static checks, types, dependency and security checks
             ↓
independent review and risk-based CI
             ↓
staged release, monitoring, and rollback
```

The layers need to be proportional to risk. A typo in documentation should not wait for the same pipeline as a database migration. A permission change or a financial calculation deserves more scrutiny than a small isolated helper. The policy should be visible and understandable, not a mysterious AI decision to run fewer tests.

AI can help at several points: draft test cases, explain a failure, identify suspicious call sites, or review a focused diff. But those are assistive signals. They do not replace deterministic checks, and a model reviewing another model's code is not independent assurance by itself.

## Why ordinary programming languages still matter

By "traditional language" I mean the languages and explicit interfaces we already use to build software: Ruby, JavaScript, Python, SQL, types, schemas, and APIs. They still matter because they make important parts of a system inspectable and executable in a repeatable way.

A Ruby method, a database constraint, or a typed API contract is more than something an AI can generate. It is a boundary that a compiler, runtime, test suite, reviewer, and future maintainer can examine. A natural-language instruction is useful for expressing intent, but it is often too flexible to serve as the only contract for a system that must behave consistently.

That is also a cost argument. AI can lower the time spent on boilerplate and routine changes. But generated code still has to be understood, tested, maintained, and run. If an agent produces a large patch that nobody can explain, the first draft may be cheap while the lifetime cost gets higher. Clear interfaces, small changes, and tests make review faster and reduce the chance that a quick implementation becomes an expensive incident.

The goal is not to choose between AI and conventional software engineering. It is to use AI to reduce the cost of producing and exploring changes, while keeping the parts that make software dependable: explicit contracts, deterministic checks, and code humans can maintain.

## Build AI-native, not AI-only

I expect better development workflows to have distinct layers rather than one agent with broad authority:

- A planning layer turns a request into an agreed scope and acceptance criteria.
- An implementation layer edits a bounded set of files and runs the relevant checks.
- A verification layer checks the diff, tests, security implications, and whether the acceptance criteria were actually met.
- A human decision layer handles ambiguous requirements, risky changes, and release approval.

Some of those layers can use AI. Some should be deterministic scripts and CI rules. The important property is separation: the same agent should not silently define the requirement, implement it, declare its own work correct, and release it without an accountable person seeing the evidence.

For a small change, this may be one developer and one agent with a short checklist. For a sensitive change, it may mean a separate reviewer, broader tests, staging, and an explicit approval. Human involvement should follow risk, not become a manual bottleneck for every trivial edit.

## Where I land

We still need TDD's core idea: make behaviour testable and use feedback to guide implementation. AI does not remove that need. It makes it easier to generate code, and easier to generate plausible tests that encode the wrong assumption.

I would keep the red-green-refactor loop where it helps, but I would not treat the order as a ritual. Write down the behaviour, choose tests that would catch a meaningful failure, let the agent help with the implementation, and inspect the evidence independently. Keep changes small enough that a human can understand what is being accepted.

AI should make good engineering cheaper, not make judgment optional.