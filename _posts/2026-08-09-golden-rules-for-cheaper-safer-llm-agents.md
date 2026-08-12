---
layout: post
title: "Golden Rules for Cheaper, Safer LLM Agents"
date: 2026-08-09 20:15:00 +0100
author: "Joey Wang"
description: "Notes on turning repeated AI workflows into scripts, skills, cron jobs, and guardrails so agents become cheaper, safer, and more useful over time."
tags: [ai, llm, agents, automation, hermes, workflows]
categories: [AI, Engineering]
start_here: true
---

# Golden rules for cheaper, safer LLM agents

A small thing happened while I was wiring a few Hermes hosts together.

I had a workflow that I could have left as a chat instruction: collect a little status from two worker machines, check that the shared knowledge repo does not contain secrets, commit the update, push it, sync the repo back to the workers, and verify that they received it.

That is exactly the kind of thing an LLM agent can do interactively.

But it is also exactly the kind of thing an LLM agent should not keep doing interactively forever.

The first run needs judgment. What should be shared? What should stay private? What is the source of truth? Which machines are allowed to decide, and which should only report evidence?

After that, the shape is mostly deterministic.

```text
collect status
  -> scan for secrets
  -> commit
  -> push
  -> rsync
  -> verify
```

So the workflow became a Python script. Then the script became a no-agent cron job.

That little promotion is one of the most important patterns I have learned from using LLM agents seriously: the LLM is not the whole system. The system is the loop around it, and the loop should get cheaper and safer every time it repeats.

## Use the cheapest layer that can do the job

The simplest rule is:

```text
LLM for judgment.
Scripts for repetition.
```

A model is useful when the work is ambiguous:

- What matters here?
- What is risky?
- Which failure is probably root cause?
- Should this become memory, a skill, a script, or a scheduled job?
- Is this public article leaking too much operational detail?

But a model is wasteful when the work is deterministic:

- count files;
- parse JSON;
- check disk space;
- list pending posts from an API;
- run the same health check every Monday;
- compare a known status output against a known policy.

That work belongs to tools, scripts, SQL, shell commands, APIs, or cron. The model can interpret the result if needed. It should not be paid to rediscover the mechanics every time.

A useful stack looks more like this:

```text
judgment / ambiguity      -> LLM
repeated procedure        -> workflow doc or skill
deterministic action      -> Python script
fast manual handle        -> slash command
scheduled deterministic   -> no-agent cron
rich searchable knowledge -> notes / docs / QMD
stable preference         -> memory
```

The hard part is not knowing these layers exist. The hard part is noticing when a task has changed layers.

## Promote repeated prompts downward

Natural language is a very good starting point. It lets me say:

```text
Review this workflow and turn it into something reusable.
```

I do not need to know the exact files or all the edge cases yet. The agent can inspect, ask questions, propose a shape, and do the first implementation.

But if I ask the same thing again and again, the prompt is trying to tell me something. It wants to move down the stack.

```text
chat prompt
  -> documented workflow
  -> skill
  -> script
  -> command
  -> cron / webhook
```

That does not mean everything should become fully autonomous. Some workflows should stop at a checklist. Some should become a skill. Some should become a dry-run script. Some should become cron only after they are boring.

The point is to stop paying tokens for rediscovery.

If I have to explain the same constraints every week, the system has not learned. It has only remembered long enough to finish the current chat.

## Verification is part of the work

A weak agent loop ends with:

```text
I changed it.
```

A stronger loop ends with:

```text
I changed it, ran the verification, and this is what happened.
```

For code, that means tests or builds. For infrastructure, it means service state and connectivity checks. For publishing, it means the page is actually live. For scheduled posts, it means the queue contains the expected text and time.

The loop should be explicit:

```text
understand
  -> gather context
  -> act
  -> verify with real output
  -> report
  -> promote the durable lesson
```

This changes the feel of working with an agent. The important output is not the confident explanation. The important output is the verified state change.

## Memory is not a dumping ground

One easy mistake is to treat memory as the place where everything should go.

That creates a different problem. If everything is memory, memory stops being useful. It becomes a noisy, always-on prompt tax.

I prefer to separate the types of knowledge:

```text
memory       -> stable facts and preferences needed every turn
skills       -> reusable procedures
notes/docs   -> rich context and longer reasoning
scripts      -> deterministic actions
Git repos    -> versioned operational history
session logs -> temporary task history
```

A stable preference belongs in memory. A procedure belongs in a skill. A long explanation belongs in a document. A repeated action belongs in a script. A change history belongs in Git.

That separation matters because each layer has a cost. Memory is paid every turn. A document is retrieved when needed. A script runs without tokens. A Git commit gives history without forcing every future prompt to carry the whole story.

Good agent design is partly information budgeting.

## Batch expensive work

Some work should not happen at the moment I have the idea.

A voice note can be captured quickly now and processed later. A knowledge base can be embedded on a schedule. A weekly review can cluster notes in a batch. A code intelligence index can run overnight or weekly instead of during every tiny question.

The pattern is:

```text
capture quickly now
process deeply later
```

This is not only about saving money. It also improves attention. Not every thought deserves an immediate deep workflow. Some thoughts should be captured cheaply and allowed to meet other related thoughts later.

For LLM systems, batching is a kind of patience.

## Primary decides; workers report evidence

When there are multiple agents or multiple hosts, it is tempting to make them all equally smart and equally authoritative.

That sounds powerful, but it can create three conflicting memories, three sets of assumptions, and three bots trying to be the final decision-maker.

A cleaner pattern is:

```text
primary agent
  -> owns memory, policy, promotion, final synthesis

worker agents
  -> run local checks
  -> collect evidence
  -> report concise results
```

Workers do not need the whole brain. They need the right local tools and a clear role.

The primary can ask a worker to check a host, run a small test, inspect a file, or verify a backup target. The worker returns evidence. The primary decides what becomes durable knowledge.

This is less glamorous than a swarm demo, but it is easier to trust.

## Approval gates are architecture

Human approval is sometimes treated as a weakness in agent systems. I think that is backwards.

For some actions, the human is not just an input device. The human is the owner of responsibility.

These actions should have explicit gates:

- production deploys;
- customer-impacting infrastructure;
- Kubernetes changes;
- secrets or credentials;
- public publishing;
- billing and cost changes;
- destructive file or database operations.

The goal is not to make the human approve every shell command. The goal is to automate everything around the meaningful decision so the approval is small, informed, and real.

```text
agent prepares
agent verifies preconditions
agent explains risk
human approves the boundary crossing
agent executes
agent verifies outcome
```

That is not slower than unsafe automation. It is faster than cleaning up after a confident mistake.

## Sanitize before sharing

Agents are very good at moving information between places.

That is useful and dangerous.

A private note can become a public blog post. A shell output can become a status report. A host runbook can become a shared repo. A social post can quote a detail that should have stayed internal.

So anything that leaves its original boundary should be scanned or reviewed for:

- tokens and keys;
- private hostnames and IPs;
- customer identifiers;
- personal email addresses;
- exact internal service names when they are not necessary;
- raw logs with sensitive content.

The standard should be boring: sanitize by default, especially when promoting internal operational work into public writing.

## Make automation reversible

A script that can only execute is usually not ready to be trusted.

Useful automation should have escape hatches:

```text
--dry-run
--no-push
--no-rsync
--skip-remote
--execute only after review
```

Dry-run mode is not just for safety. It makes the script easier to reason about. It shows what the automation believes it is about to do.

That is exactly the kind of surface an LLM can review well: not a vague intention, but a concrete planned action.

## Turn repeated failures into guardrails

If a failure happens once, fix it.

If it happens twice, encode the lesson.

That might mean:

- add a preflight check;
- patch a skill;
- update a runbook;
- make a script refuse unsafe input;
- add a secret scan;
- add a verification command;
- schedule a deterministic watchdog.

The best agent systems do not become smarter only because the model improves. They become smarter because the environment accumulates guardrails.

A repeated mistake should not become a heroic debugging story every time. It should become harder to repeat.

## The real interface is not the chat box

The chat box is where the interaction starts, but it is not the whole interface.

The real interface is a living system:

```text
human intention
  -> LLM judgment
  -> tools and scripts
  -> versioned knowledge
  -> scheduled checks
  -> verification
  -> human approval where needed
  -> improved procedures
```

That is why I think the interesting question is no longer only “how do I prompt this model?”

The better question is:

> How should this work evolve after the first successful run?

If the answer stays as a prompt forever, it will keep costing attention and tokens.

If the answer becomes a skill, a script, a cron job, a guardrail, or a documented decision, the system has actually learned.

That is the practical promise of LLM agents for me: not replacing judgment, but turning repeated judgment into better tools around future judgment.

The model is powerful.

But the compounding value is in the workflow you leave behind.
