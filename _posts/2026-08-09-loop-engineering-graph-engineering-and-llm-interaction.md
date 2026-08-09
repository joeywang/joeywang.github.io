---
layout: post
title: "Loop Engineering, Graph Engineering, and the Nature of Working with LLMs"
date: 2026-08-09 18:37:00 +0100
author: "Joey Wang"
description: "A practical reflection on prompt engineering, context engineering, loop engineering, graph engineering, and what they reveal about the shape of human interaction with LLMs."
tags: [ai, llm, agents, loop-engineering, graph-engineering, hermes]
categories: [AI, Engineering]
---

# Loop engineering, graph engineering, and the nature of working with LLMs

When people first meet an LLM, the interaction looks simple.

You type something. The model replies.

```text
human -> prompt -> model -> answer
```

That picture is not wrong, but it is too small. It describes the chat box, not the work.

The more I use LLMs inside daily engineering and life systems, the less I think the interesting part is the prompt by itself. The interesting part is the structure around the model.

We started with prompts. Then context. Then agents. Then memory. Then tools. Now I keep coming back to two bigger shapes: **loops** and **graphs**.

Loop engineering is about how an AI system keeps doing useful work.

Graph engineering is about how an AI system understands relationships.

Both matter. They are not the same thing.

## Prompt engineering was the first layer

Prompt engineering was the first vocabulary most of us learned.

Ask clearly. Give examples. Specify the format. Tell the model what role to take. Add constraints. Say what good output looks like.

That still matters. A vague request gets vague work. A precise request gives the model more handles.

```text
Bad:
  Help me with this bug.

Better:
  Read the failing test, explain the likely root cause,
  make the smallest safe change, then run the focused test.
```

But prompt engineering has a ceiling.

A prompt is a moment. It depends on what I remember to say this time. It lives inside one conversation. If I have to retype the same careful instruction every week, I have not built a system. I have built a little ritual.

That is fine when I am exploring. It is not enough for reliable work.

## Context engineering made the prompt less lonely

The next layer is context engineering.

The question becomes: what should the model know before it answers?

That might be:

- the current file;
- the failing test output;
- the relevant pull request;
- personal preferences;
- old notes;
- documentation;
- a previous decision;
- the command that verifies the result.

This is where notes, search, session history, RAG, and code tools enter the picture.

The model is not only generating from training data. It is being placed inside a local situation.

```text
request
  + current files
  + logs
  + notes
  + memory
  + docs
  -> better answer
```

Context engineering changes the interaction from asking a clever stranger to asking a temporary teammate who has read the room.

But context also has a problem. Too little context makes the model guess. Too much context makes the model drown. Wrong context can be worse than no context, because it gives confidence to the wrong path.

So the skill is not “add more context”.

It is choosing the right context for the next action.

## Tool engineering gave the model hands

A plain LLM can describe a command. An agent with tools can run it.

That changes the interaction.

```text
model says: run the test
agent does: run the test
agent reads: real output
model decides: next step
```

The model does not need to pretend it knows whether the test passes. It can check. It does not need to invent the file contents. It can read the file. It does not need to guess the current branch. It can ask Git.

Tool engineering is partly about giving the model capabilities. More importantly, it removes the temptation to hallucinate.

If the system can observe the world, it should observe the world.

## Memory engineering gave the system continuity

A single LLM conversation can be useful. A long-running assistant needs memory.

But memory is not “save everything”. That is another way to drown the model.

Different things belong in different places:

```text
stable facts        -> memory
reusable procedure -> skill or workflow
documents/notes    -> searchable knowledge base
code relationships -> code graph
one-off progress   -> session history
commands           -> scripts or slash commands
scheduled work     -> cron or webhook
```

This separation matters because each type of knowledge has a different half-life.

My preference for concise status reports is stable. A failed test output from this morning is not. A workflow for preparing a blog post may be reusable. The exact draft path is temporary. A production deploy rule may be durable. A branch name may be stale tomorrow.

Good memory engineering is not about making the AI remember everything.

It is about making it forget less stupidly.

## Loop engineering is the agent shape

Once the model can read context, use tools, and remember durable lessons, the question changes.

What loop should it run?

For me, a useful agent loop looks something like this:

```text
capture
  -> retrieve
  -> plan
  -> act
  -> verify
  -> report
  -> remember/promote
```

This is loop engineering.

It is the difference between a model that answers and a system that works.

A good loop observes before acting. It reads the file, checks the branch, inspects the error, searches the notes, or asks for the missing decision.

It acts in small steps. It does not rewrite the whole system when a focused patch would do.

It verifies with reality: tests, builds, live URLs, logs, API responses, file checks, timestamps. Not vibes.

It knows when to stop. Infinite autonomy is not intelligence. Sometimes the correct next step is to report a blocker or ask for approval.

It promotes repeated work. If I keep asking the same thing, the loop should move from chat into a workflow, then maybe a command, script, API, cron job, or product feature.

This is why I think loop engineering is the default best practice for an assistant like Hermes. Hermes is not only a model endpoint. It is a tool-using, memory-backed, scheduled, multi-surface agent. The natural unit is not the prompt. It is the verified loop.

## Graph engineering is the relationship shape

Graph engineering answers a different question.

What is connected to what?

A graph can represent code symbols, documents, people, decisions, projects, dependencies, concepts, tasks, APIs, or memories.

```text
concept: loop engineering
  -> related to: agent design
  -> related to: verification
  -> related to: memory promotion
  -> used in: weekly review workflow
  -> supported by: tools, skills, cron
```

In code, a graph can tell me which functions call another function, which route reaches which service, or what might break if I change a model field.

In notes, a graph can show that an idea from a voice note connects to a blog draft, a work process, and a product decision.

In memory, a graph can connect a person, a preference, a repo, and a repeated workflow.

This is useful because LLMs are very good at language, but real work is full of relationships. The answer often depends less on one document and more on the path between several things.

Graph engineering gives the agent better maps.

But a map is not the journey.

## Loop-first, graph-assisted

This is the distinction I keep coming back to.

For an AI assistant, graph engineering should usually support the loop. It should not replace the loop.

The graph helps the system retrieve the right context:

```text
What code path is affected?
What note is connected to this idea?
What previous decision applies here?
What dependency might be touched?
```

The loop decides what to do with that context:

```text
inspect
plan
change
test
report
promote
```

So my current rule is:

```text
loop engineering for action
graph engineering for understanding
```

If the task is “fix this”, “draft this”, “review this”, “prepare this”, or “monitor this”, I want a loop.

If the task is “what is related?”, “what depends on this?”, “where is this used?”, or “what context matters?”, I want a graph.

The best systems combine them, but they should not confuse them.

## Human-in-the-loop is not a weakness

There is one more loop that matters: the human loop.

A lot of AI demos quietly assume that the best system is the one that removes the human as much as possible. Sometimes that is true. I do not want to manually rotate log files or retype the same invoice calculation forever.

But for many tasks, the human is not just a source of commands. The human is the owner of judgment.

Deploying to production, changing customer-facing infrastructure, exposing secrets, sending emails, publishing posts, making family decisions, spending money: these are not just technical actions. They carry responsibility.

A good agent should know which loop it is inside.

```text
safe deterministic task
  -> automate

repeated but judgment-heavy task
  -> workflow + review

sensitive external side effect
  -> explicit approval
```

The goal is not maximum autonomy everywhere.

The goal is appropriate autonomy.

## The nature of interaction with LLMs

This is the part I think people underestimate.

LLMs are not normal software components. They are not databases. They are not search engines. They are not humans either.

They are strange language engines that can temporarily inhabit a context, make plausible plans, call tools, explain uncertainty, and then lose the shape of the work unless we build structure around them.

So the interaction is not simply instruction and response.

It is setting up conditions for situated reasoning.

```text
Give the model the right role.
Give it the right context.
Give it tools to observe reality.
Give it a loop that checks its work.
Give it memory for durable lessons.
Give it graphs for relationships.
Give it human approval where responsibility matters.
```

Then the model becomes less like an oracle and more like a moving part in a thinking system.

That feels like the shift.

Not “AI will answer everything”.

More like: we are learning how to build systems where language, tools, memory, graphs, and human judgment keep passing state between each other.

## A practical stack

If I had to explain the stack from bottom to top, I would describe it like this:

```text
Prompt engineering
  Say the thing clearly.

Context engineering
  Bring the right facts into the room.

Tool engineering
  Let the model observe and act.

Memory engineering
  Preserve durable lessons without polluting the present.

Graph engineering
  Map relationships between code, notes, people, tasks, and decisions.

Loop engineering
  Turn all of the above into repeated, verified work.

Human judgment
  Decide what should be automated, reviewed, approved, or refused.
```

Each layer solves a different failure mode.

Prompts reduce ambiguity. Context reduces ignorance. Tools reduce hallucination. Memory reduces repetition. Graphs reduce isolation. Loops reduce drift. Human judgment reduces irresponsible automation.

That is a more useful mental model than arguing whether “prompt engineering is dead”.

Prompting did not die. It became one layer in a larger system.

## Where I am landing

For Hermes, and probably for most serious personal agents, I think the best practice is:

```text
loop-first, graph-assisted, human-governed
```

Use loops to make the assistant reliable.

Use graphs to make the assistant aware of relationships.

Use memory and skills to make it improve over time.

Use tools and verification to keep it grounded.

Use human approval where the cost of being wrong is not just a bad answer.

That is the basic understanding I want to keep building.

The interesting question is no longer only “what should I type into the LLM?”

It is:

What kind of interaction am I building around it?
