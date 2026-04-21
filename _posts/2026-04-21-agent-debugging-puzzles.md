---
layout: post
title: "Tiny Puzzles for Testing and Debugging AI Agents"
date: 2026-04-21
author: "Joey Wang"
description: "A practical guide to building small probe tasks to test function calling, skill awareness, prompt length, cache behavior, and runtime debugging for local AI agents."
tags: [ai, llm, agents, debugging, testing, lm-studio, pi, opencode, local-llm]
categories: [AI, Engineering]
---

# Tiny Puzzles for Testing and Debugging AI Agents

One thing I keep coming back to with local agents is this: if you only test them on real work, debugging takes forever.

A big task fails and you do not know why.

Was function calling broken?
Did the model ignore the skill instructions?
Did the prompt get too long?
Did the agent runtime format messages wrong?
Did LM Studio drop some warning you only notice after the fact?

When the task is large, every failure mode gets mixed together. That makes the whole setup feel mystical when it usually is not.

What helped me was building tiny puzzles.

By "puzzle," I do not mean benchmark games or synthetic IQ tests. I mean small, repeatable probe tasks that isolate one capability at a time. A good puzzle gives you a yes-or-no answer about one layer of the stack.

That is much more useful than asking a vague question and hoping the agent "feels smart."

## What I actually want from a puzzle

A good agent-debugging puzzle should be:

- **small** enough to run in seconds
- **repeatable** enough to compare across models or prompt changes
- **narrow** enough to isolate one failure mode
- **cheap** enough that I can run it many times
- **observable** enough that I can inspect logs and understand what happened

If the task is too broad, you learn almost nothing.

That is why I like tests like:

- "call exactly one tool"
- "use the right skill when the trigger phrase appears"
- "survive a prompt that is 3x longer than the easy case"
- "repeat the same prompt twice and see whether cache behavior changes"

Those are not glamorous. They are useful.

## The basic idea: build a probe suite, not one giant eval

I would break agent testing into five buckets:

1. function calling support
2. skill awareness
3. prompt-length and context pressure
4. debugging by layer: agent runtime vs model runtime
5. metrics, logs, and traces

You can think of this as a cheap local eval harness for yourself.

## 1. Test function calling support first

This is the first thing I test because if it is broken, everything above it becomes noise.

The goal here is not "can the model describe tool use?" The goal is "can the model produce the exact structured action the runtime needs, and can the runtime round-trip the result correctly?"

### The simplest puzzle

Give the agent one tool and one obvious task.

For example:

> You have one tool: `read_file(path)`.
> Read `README.md` and tell me the first sentence.

Why this works:

- only one tool is available
- the right action is obvious
- the result is easy to verify
- failure is easy to classify

Possible outcomes:

- it calls the tool correctly: good
- it answers without the tool: prompt or runtime issue
- it emits malformed tool JSON: model formatting issue
- it calls the wrong tool: tool selection issue
- it calls the tool but ignores the result: loop or message formatting issue

### Slightly better function-call puzzles

Once the trivial case passes, I like a short ladder:

1. one tool, one obvious call
2. two tools, only one correct choice
3. two sequential tool calls
4. read, then patch, then verify
5. multiple independent reads in parallel

That ladder tells you where the system starts to break.

### What I look for in logs

At this stage, I want to see:

- the full prompt sent by the agent
- the tool schema exposed to the model
- the raw model output before the runtime sanitizes it
- the parsed tool call
- the returned tool result
- the next model turn after the tool result

If any one of those is missing, debugging gets much harder.

## 2. Test skill awareness separately

This one is easy to confuse with general intelligence.

If you use skills, rulesets, or task-specific system instructions, you should test whether the agent notices and follows them before you test complicated work.

The puzzle here is not "is the output good?" The puzzle is "did the agent notice the right behavior cue?"

### A good skill-awareness puzzle

Create two nearly identical tasks where only one should trigger the skill.

For example:

- Task A: "Summarize this file."
- Task B: "Humanize this article."

If the `humanizer` skill is available and Task B does not activate the expected behavior, that is not a generic writing failure. That is a skill-selection failure.

### Another useful pattern

Make the skill instruction produce a visible artifact.

Examples:

- a required heading
- a required command pattern
- a required output shape
- a required refusal to do some prohibited action

That way you can verify whether the skill was active without guessing.

### Failure modes to watch

- the skill never enters context
- the skill enters context but gets ignored
- the skill conflicts with stronger system instructions
- the skill works on short prompts but disappears on long ones
- the skill triggers, but only partially

That last one is common. The agent acts like it vaguely remembers the rule but not enough to follow it cleanly.

## 3. Test prompt length and context pressure on purpose

This is where local setups get weird fast.

A model can look fine on a short prompt and then fall apart once you add:

- a large system prompt
- a skill catalog
- tool schemas
- a long file
- a diff
- previous turns

That is not a minor edge case. That is the normal shape of agent work.

So I like to test prompt pressure deliberately instead of waiting for a real task to reveal it.

### The ladder I use

Run the same task at different prompt sizes:

1. tiny prompt
2. normal prompt
3. long prompt
4. long prompt plus previous turns
5. long prompt plus tools plus previous turns

The task itself should stay almost the same. Only the context load changes.

That helps answer a very useful question:

> Is the model bad at the task, or is the system bad under context pressure?

### A cheap KV-cache probe

One of my favorite tiny tests is embarrassingly simple:

1. send `hello`
2. send `hello again`

I am not using that to test intelligence. I am using it to test cache behavior and runtime traces.

If the stack supports prompt caching or KV reuse, I want to see evidence in latency, logs, or runtime counters. If I expect cache reuse and nothing changes, that is already a clue.

This is where I often check LM Studio logs. I want to see:

- whether the requests actually reached the model runtime
- whether there are warnings about cache support
- whether the second request behaves differently
- whether the runtime reports any unsupported cache path

That tiny test is not sufficient, but it is cheap and surprisingly revealing.

### Another prompt-length puzzle

Ask the model to follow one simple instruction buried at the very end of a long prompt.

For example:

> After reading everything above, answer with exactly: `CACHE_OK`

If it misses that reliably only when the prompt gets large, you have learned something real about instruction retention under load.

## 4. Debug by layer: agent problem or model problem?

This is the distinction that saves the most time.

When an agent fails, I try to ask:

1. Did the agent send the right prompt?
2. Did the model return something usable?
3. Did the runtime parse it correctly?
4. Did the tool result get fed back in the right shape?
5. Did the loop stop too early or continue too long?

If you do not separate those layers, you end up rewriting prompts when the real problem is message formatting, or blaming the model when the real problem is unsupported KV cache in the backend.

### My rough debugging stack

I usually debug in this order:

#### Layer 1: agent client

This is Pi, OpenCode, OpenHands, or whatever harness you are using.

Questions:

- What exact system prompt did it send?
- What tools did it expose?
- Did it strip or rewrite any message roles?
- Did it truncate context?
- Did it retry without telling me?
- Did it sanitize model output before I saw it?

This layer is responsible for a lot more weirdness than people expect.

#### Layer 2: transport / API compatibility

Questions:

- Did the request format match what the backend expects?
- Are tool calls encoded the way the runtime expects?
- Are reasoning channels or special tokens being passed through cleanly?
- Is the compatibility mode wrong for this backend?

This layer is boring until it is broken. Then everything looks cursed.

#### Layer 3: model runtime

For a local stack, this is where LM Studio, Ollama, MLX, llama.cpp, or another runtime starts to matter.

Questions:

- Did the model start generating?
- Did it stall at 0%?
- Did it leak think tags?
- Did it warn about unsupported KV caching?
- Did it hit memory pressure?
- Did it silently fall back to a degraded path?

This is why I check LM Studio logs so often. If the runtime is complaining, I want to know before I waste an hour blaming the prompt.

#### Layer 4: model behavior

Only after the first three layers look healthy do I spend much time blaming the model itself.

Questions:

- Did the model choose the wrong tool?
- Did it ignore a strong instruction?
- Did it lose track of prior context?
- Did it produce malformed structured output?

Sometimes the answer really is "the model is weak at this." But that should be the last conclusion, not the first.

## 5. Metrics, logs, and traces: what I actually want

If you are serious about debugging agents, text output alone is not enough.

You want a trace.

At minimum, I would want:

- request timestamp
- model name
- prompt token count or prompt length estimate
- completion length
- latency to first token
- total latency
- tool calls emitted
- tool-call parse failures
- retries
- stop reason
- cache hit or cache reuse signals if available
- warnings from the model runtime

That is the minimum useful set.

### The most useful derived metrics

Once you have the basics, the metrics I care about most are:

- **tool-call success rate**: how often the raw output becomes a valid tool call
- **tool round-trip success rate**: how often the model continues correctly after getting a tool result
- **instruction retention under load**: does the model still obey the obvious rule in long prompts
- **latency by prompt size**: when does the system start to bend
- **failure clustering**: are most failures coming from one layer

That last one matters because random-seeming instability often is not random at all. It clusters around one part of the stack.

## A practical probe suite I would keep around

If I were setting this up from scratch, I would keep a small set of named probes.

### Probe 1: single-tool sanity check

Goal: verify basic tool calling.

Prompt:

> Use the available file-read tool to read `README.md` and return only its first sentence.

### Probe 2: tool-loop continuation

Goal: verify that the agent continues after a tool result instead of narrating.

Prompt:

> Read `README.md`, then tell me how many top-level sections it has.

This forces a read, then a second reasoning step based on the returned content.

### Probe 3: skill trigger check

Goal: verify that the right skill or ruleset activates.

Prompt:

> Humanize the following draft.

Expected result: visible behavior that clearly matches the skill instructions.

### Probe 4: buried instruction retention

Goal: check prompt-pressure behavior.

Prompt:

> [long filler context]
> Final instruction: reply with exactly `CACHE_OK`

### Probe 5: cache reuse smoke test

Goal: see whether repeated prompts behave differently.

Prompt sequence:

1. `hello`
2. `hello again`

This is not deep, but it is cheap. For local debugging, cheap matters.

### Probe 6: runtime warning trap

Goal: catch backend-specific failures early.

Procedure:

1. run one short prompt
2. run one long prompt
3. inspect LM Studio logs

I want to catch things like:

- unsupported KV cache paths
- prompt stalls
- memory pressure warnings
- reasoning-tag leakage

### Probe 7: patch-and-verify microtask

Goal: test the full coding loop in miniature.

Prompt:

> Read `foo.txt`, replace `cat` with `dog`, then verify the file changed.

This sounds silly, but it exercises the real sequence:

- read
- patch
- observe
- continue

That makes it more valuable than a pure text-generation test.

## What makes a puzzle good?

The best puzzles are not the most clever ones. They are the ones that make failure obvious.

Bad puzzle:

> "Review this medium-sized repository and suggest improvements."

If it fails, you learn almost nothing.

Better puzzle:

> "You have one tool. Read one file. Return one sentence."

If it fails, you know where to look.

That is the mindset shift.

Do not start by asking whether the agent is smart. Start by asking whether one layer of the system is behaving.

## The point is not to win the puzzle

This is worth saying because people drift into benchmark brain very easily.

The goal of these puzzles is not to prove that one model is superior in the abstract. The goal is to make the stack debuggable.

That means:

- isolate one variable
- keep the task cheap
- inspect the logs
- compare runs after each config change
- only then move back to real work

I still care about real tasks in the end. Of course I do. But I do not trust a real-task result very much if I do not have a clean probe suite underneath it.

That is especially true for local agent setups, where a lot of failures come from runtime behavior, prompt overhead, API compatibility, or cache paths rather than from some deep model limitation.

## What I would do first in a local LM Studio setup

If I were debugging Pi or OpenCode against LM Studio from scratch, I would do this in order:

1. Run a one-line plain text prompt and confirm the backend is alive.
2. Run a one-tool puzzle and confirm tool calling works.
3. Run the same task with a longer prompt and compare latency and output quality.
4. Run the `hello` / `hello again` cache smoke test.
5. Inspect LM Studio logs after both short and long prompts.
6. Only then try a real coding task.

That order is boring. It also saves time.

## Final takeaway

When an agent fails, I do not want a mystery. I want a small broken puzzle.

That is what lets me debug one layer at a time:

- tool calling
- skill awareness
- prompt pressure
- runtime health
- logs and metrics

Real work is too expensive to be your only test harness.

Tiny puzzles are cheaper. And for debugging, cheaper usually wins.
