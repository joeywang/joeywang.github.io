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

The first time I tried to wire a local coding agent around Gemma, I thought the hard part would be the model.

It wasn't.

The model looked flaky because my agent loop was flaky.

One of the first tasks I gave it was boring on purpose: find a file, make a small code change, then run the relevant test. The model did the first part correctly. It asked for the file. It asked for the test. Then it drifted. Instead of taking the next tool step, it started explaining what should happen next like a consultant writing a checklist.

At first glance that looked like a model failure. It wasn't. I was parsing the response stream too early and mishandling the turn after the tool result. The model never really got a clean chance to continue.

That changed how I think about coding agents.

A coding agent is not just a model with a bigger prompt. It is a small software system wrapped around a model. The model does the reasoning. The runtime does the state management, tool execution, file edits, and validation.

That distinction matters because people blame or praise "the model" for things the surrounding harness is actually doing.

After spending time with Gemma and OpenCode-style local workflows, I keep coming back to the same conclusion: the model is only one part of the system. The loop around it is what turns text generation into software work.

If I had to reduce the whole article to one line, it would be this:

> Most of what feels magical in a coding agent is just a model sitting inside a well-built loop.

## What the system actually is

At a high level, a coding agent has five moving parts:

1. The **model** that interprets the request and decides what to do next
2. The **prompt and context builder** that prepares instructions and relevant repository state
3. The **tool runtime** that executes shell commands, file reads, searches, and patches
4. The **agent loop** that keeps calling the model after each tool result
5. The **verification layer** that runs tests, linters, or builds before returning control

A normal chatbot answers once. An agent reads, acts, checks what happened, then goes again.

Here is the simplest version of the flow:

```text
User request
  -> context builder
  -> model
  -> tool call
  -> runtime executes tool
  -> tool result goes back to model
  -> patch / command / follow-up tool call
  -> tests or lint
  -> final answer
```

That diagram is not glamorous, but it explains more of the experience than model marketing ever will.

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

## A tiny end-to-end example

This is what a healthy loop looks like in practice.

Imagine the user asks:

> "Fix the failing login test."

What happens next is usually something like this:

1. The agent searches for the failing test or runs a narrowed test command.
2. The runtime sends the failure output back to the model.
3. The model asks to read `auth.rb` and the matching test file.
4. The runtime returns both file contents.
5. The model proposes a small patch.
6. The runtime applies the patch.
7. The model asks to rerun the test.
8. The runtime returns either a pass or a new failure.
9. If it still fails, the loop continues.

In rough pseudo-transcript form:

```text
user: Fix the failing login test.

assistant -> tool: run_test("bundle exec rspec spec/requests/login_spec.rb")
tool -> assistant: failure in "returns 401 for expired token"

assistant -> tool: read_file("app/services/auth.rb")
assistant -> tool: read_file("spec/requests/login_spec.rb")
tool -> assistant: [file contents]

assistant -> tool: apply_patch(...)
tool -> assistant: patch applied

assistant -> tool: run_test("bundle exec rspec spec/requests/login_spec.rb")
tool -> assistant: 1 example, 0 failures

assistant: Fixed. The token expiry check was comparing strings instead of timestamps.
```

That is the job. Not one huge leap of intelligence. A sequence of small moves, each grounded in feedback.

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

## Where agents usually break

When people say a coding agent "just kind of fell apart," the failure is often boring:

- the model emitted a tool call across multiple stream chunks and the runtime acted too early
- the tool result got appended in the wrong format
- the agent lost the thread after a long wall of shell output
- the patch applied, but the model never saw the real post-patch state
- the system skipped verification and returned confident nonsense

This is why I am suspicious of sweeping claims about model quality without any discussion of runtime quality. A fragile harness can make a good model look bad. A disciplined harness can make a merely decent model feel much better than expected.

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

## Why this gets harder locally

This point matters even more for local agents.

Cloud coding products usually have polished runtimes, mature prompt formatting, and enough infrastructure around the model that a lot of rough edges are hidden from the user. Local setups are less forgiving.

You run into issues like:

- tighter memory limits
- smaller practical context windows
- worse latency when you overfeed the model
- more brittle tool calling
- more prompt-format sensitivity
- less guardrail infrastructure around long sessions

That does not make local agents pointless. I still like them. It just means the boring systems work matters even more. If your local agent feels unstable, it may not need a smarter model first. It may need a better loop, cleaner context, and stricter verification.

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

## Final takeaway

An LLM coding agent does not build software by generating one brilliant answer.

It builds software by repeatedly doing four things well:

1. gathering the right context
2. choosing the next action
3. executing that action through tools
4. checking the result against reality

If you want to build a better local agent, spend less time imagining a magical autonomous coder and more time improving those four steps.

What looks like intelligence is often just good plumbing.
