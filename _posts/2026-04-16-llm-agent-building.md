---
layout: post
title: "How an LLM Coding Agent Actually Builds Software"
date: 2026-04-16
author: "Joey Wang"
description: "A practical breakdown of how coding agents work: model, tool loop, context management, patching, and verification."
tags: [ai, llm, agents, coding-agent, gemma, opencode, software-engineering]
categories: [AI, Engineering]
---

# How an LLM Coding Agent Actually Builds Software

The first time you use a coding agent, it is tempting to describe it as "ChatGPT, but it can edit files."

Close enough for dinner conversation, wrong enough to cause confusion the moment you try to build one yourself.

A coding agent is not just a model with a bigger prompt. It is a small software system wrapped around a model. The model does the reasoning. The runtime does the state management, tool execution, file edits, and validation.

That distinction matters because people blame or praise "the model" for things the surrounding harness is actually doing.

After spending time with Gemma and OpenCode-style local workflows, I keep coming back to the same conclusion: the model is only one part of the system. The loop around it is what turns text generation into software work.

## What the system actually is

At a high level, a coding agent has five moving parts:

1. The **model** that interprets the request and decides what to do next
2. The **prompt and context builder** that prepares instructions and relevant repository state
3. The **tool runtime** that executes shell commands, file reads, searches, and patches
4. The **agent loop** that keeps calling the model after each tool result
5. The **verification layer** that runs tests, linters, or builds before returning control

A normal chatbot answers once. An agent reads, acts, checks what happened, then goes again.

---

## Step 1: build the working context

Before the model can do useful work, the agent has to decide what context to provide.

That usually includes:

- system instructions
- the user's request
- recent conversation history
- tool definitions
- repository structure or symbol summaries
- relevant file contents or search results

This part gets hand-waved a lot. The agent is not dumping an entire repository into the model. It is trying to assemble a useful working set.

In practice, good agents do some combination of:

- **repository mapping**: build a high-level view of files, symbols, or modules
- **targeted retrieval**: read only the files that look relevant
- **context trimming**: keep the active state small enough to fit the model's window
- **caching**: avoid re-reading the same large context on every turn

The important point is simple: context is assembled. It is not magically remembered.

## Step 2: let the model decide the next move

Once the context is ready, the model gets a turn.

For a coding task such as "fix the failing login flow," the model is not supposed to immediately output code. A good model will first decide what information it still needs:

- inspect the auth code
- search for the failing controller or service
- read the relevant test
- run the test suite or a narrowed test target

This is where reasoning helps, but reasoning on its own is not enough. If the runtime does not support tools and iteration, the model can only describe a plan. It cannot carry it out.

That is the gap between:

- "You should inspect `auth.rb` and run the tests"
- actually reading `auth.rb`, running the tests, seeing the failure, and proposing a patch

If you have built one of these loops badly, you can feel the difference immediately. The model sounds smart. Nothing gets done.

## Step 3: turn intent into tool calls

The model does not directly touch your filesystem. It emits structured intent.

Depending on the runtime, that may look like a function call, JSON object, or tool invocation block. The meaning is the same:

> "Run this shell command."
>
> "Read this file."
>
> "Apply this patch."

This is one of the most useful mental models in agent design:

> **The model does not execute tools. The runtime executes tools.**

That separation is what makes the system manageable. The runtime can validate arguments, reject unsafe actions, log everything, and feed the results back into the conversation.

It also means a lot of agent bugs are not really model bugs. They are runtime bugs:

- tool calls parsed incorrectly
- partial streaming output handled too early
- malformed tool results appended to history
- message roles mismatched for the target model
- missing loop after a tool result

I ran into exactly this kind of problem in my own local setup. The model looked flaky until I realized the harness was the flaky part.

## Step 4: execute, observe, loop

This is the part many first-time agent builders miss.

The basic loop looks like this:

```python
messages = initial_context

while True:
    response = llm(messages, tools=tools)

    if response.tool_calls:
        messages.append(response)

        for call in response.tool_calls:
            result = execute_tool(call)
            messages.append(result)

        continue

    return response.final_text
```

The crucial line is `continue`.

After each tool result, the model needs another turn. That is how it moves from:

1. reading files
2. forming a hypothesis
3. patching code
4. running tests
5. adjusting the patch if the tests still fail

Without that loop, you do not have much of an agent. You have a one-shot assistant that knows how to talk about tool syntax.

---

## Step 5: make precise edits instead of rewriting everything

When the agent decides to change code, the safest path is usually not "rewrite the whole file."

Better runtimes prefer targeted edits such as:

- search-and-replace for a unique block
- line-oriented patching
- unified diff application

That approach helps for two reasons:

1. It reduces accidental damage to unrelated code.
2. It gives the model a more stable editing primitive for iterative fixes.

This is one reason patch-based workflows feel noticeably more reliable than naive "rewrite the whole file" approaches.

## Step 6: check the work against reality

An agent is only useful if it can compare its changes against reality.

For software tasks, "reality" usually means one or more of:

- tests
- linters
- type checks
- builds
- runtime output

The model proposes a change. The runtime runs the relevant checks. The model then sees the result and decides whether the job is actually done.

That is the difference between a flashy demo and a tool you might actually trust. The demo stops when the code looks plausible. The useful tool stops when the environment says the change holds up.

---

## Context management is where things quietly break

As the session gets longer, the agent's job gets harder.

Every tool result, file read, and patch explanation consumes context window space. If you keep everything, the model eventually drowns in stale logs and low-value history.

So real agents need compaction strategies:

- keep recent turns verbatim
- summarize older work
- drop noisy command output
- retain the current plan and latest repository state
- preserve durable instructions while discarding dead ends

This is not the glamorous part of agent design, but it matters more than people think. A lot of agent failures are really context failures wearing a fake mustache.

## The model matters, but the harness matters more

Different models are better or worse at planning, tool use, structured output, and code generation. That absolutely affects the experience.

But once you start building agents, you realize something uncomfortable:

> A strong model in a weak harness is frustrating. A decent model in a strong harness is often more useful than it has any right to be.

The harness determines whether the model can:

- find the right file
- survive long sessions
- recover from failed commands
- apply surgical edits
- prove that the task is complete

That is why two products using similarly capable models can feel wildly different in practice.

## A better way to think about coding agents

The mental model I keep settling on is this:

- the **model** is the reasoning engine
- the **agent runtime** is the operating system around that engine

The runtime gives the model senses, memory, and hands:

- **senses** through file reads, search, test output, and external tools
- **memory** through conversation state, summaries, and cached repository context
- **hands** through patches, shell commands, and API calls

Once you see the system that way, a lot of confusing behavior stops being confusing. You stop asking, "Why didn't the model just do it?" and start asking the more useful question:

> "What part of the agent loop failed?"

---

## Final takeaway

An LLM coding agent does not build software by generating one brilliant answer.

It builds software by repeatedly doing four things well:

1. gathering the right context
2. choosing the next action
3. executing that action through tools
4. checking the result against reality

If you want to build a better local agent, spend less time imagining a magical autonomous coder and more time improving those four steps.

That is the real work.
