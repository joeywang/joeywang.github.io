---
layout: post
title: "Don't Leave Good AI Workflows in Chat"
date: 2026-07-31 17:48:57 +0100
author: "Joey Wang"
description: "A practical note on promoting repeated AI workflows into slash commands, scripts, APIs, and scheduled jobs, with the trade-offs between judgment, cost, performance, and safety."
tags: [ai, agents, automation, workflows, hermes, commands]
categories: [AI, Engineering]
---

<audio controls preload="metadata" src="/assets/audio/promoting-ai-workflows-into-commands-summary.ogg">
  Your browser does not support the audio element.
</audio>

# Don't leave good AI workflows in chat

I started with a small housekeeping question to my agent:

> Review the workflow and scripts to see anything we can convert to `/command` to use.

That sounds like a tiny UX tweak. A few shortcuts. Maybe a command to check provider usage, another one to run a local security watchdog.

But the more I looked at it, the more it felt like a general pattern for working with AI agents.

A useful AI workflow should not stay as a long chat prompt forever. If I keep asking for the same thing, the workflow is telling me it wants to move somewhere cheaper, faster, and more reliable.

Not everything should move all the way down. Some things need judgment every time. Some things are expensive and should run in batches. Some things are dangerous and should stay behind explicit confirmation.

But repeated work should be promoted.

```text
natural language request
  -> documented workflow
     -> slash command
        -> Python / Bash script
           -> API
              -> cron / webhook / batch job
```

The trick is knowing which layer the work belongs in.

## The first version is usually just a prompt

Natural language is a good starting point because it is flexible.

When I say:

```text
Review my workflows and scripts and tell me what can become commands.
```

I do not need to know the exact files, options, names, or implementation details. The agent can inspect the repo, read workflow docs, look at existing scripts, compare them against Hermes quick command behavior, and come back with recommendations.

That is exactly where an LLM is useful. The task has judgment in it:

- Is this script safe to expose as a command?
- Does it need arguments?
- Does it depend on credentials?
- Is it fast enough for a chat command?
- Should it run through the agent or bypass the agent?
- Is this really a command, or should it remain a scheduled job?

A script cannot answer those questions unless I have already encoded the policy. The LLM can reason through it while the workflow is still messy.

The downside is obvious once you repeat the task. Natural language is expensive. It consumes context. It depends on how well I phrase the request today. It may rediscover the same facts it discovered last week.

That is fine for exploration. It is wasteful for muscle memory.

## The second version is a workflow

Once the shape is clear, I want a documented workflow or a skill.

For this case, the workflow is something like:

```text
Capture -> Structure -> Store -> Retrieve -> Reason -> Act -> Verify -> Remember
```

That is the Hermes capture-to-action loop I have been building around voice notes, QMD, scheduled reviews, skills, and local scripts.

The workflow document is still language, but it is no longer a fresh prompt. It has a name. It has guardrails. It says which sources to check and which outputs to produce. It records the distinction between stable memory, retrievable notes, reusable skills, deterministic scripts, and scheduled jobs.

This is already an improvement. The LLM can still adapt, but it is not starting cold.

A workflow is a good place for tasks that are repeated but not completely deterministic:

- review recent voice notes and cluster ideas;
- turn an approved promotion note into a concrete artifact;
- inspect a project and propose the next action;
- produce a weekly planning brief from calendar, email, and notes;
- decide whether a routine should become a skill, script, command, cron job, or code feature.

The agent still does real thinking. The workflow just stops it from thinking from scratch every time.

## Slash commands are the middle layer

Slash commands are interesting because they sit between natural language and code.

They are still a chat interface. I can use them from Telegram on my phone. But they remove the repeated prompt-writing step.

Instead of typing:

```text
Use the approved promotion execution workflow from the QMD workflow library.
Read this promotion note, classify the lane, build the local artifact, verify it, and ask me before any external side effects.
/home/ubuntu/study/hermes-promotions/some-note.md
```

I can type:

```text
/promote /home/ubuntu/study/hermes-promotions/some-note.md
```

That is a big difference in practice.

The command name becomes a handle for the workflow. It also becomes a contract. `/promote` should mean a known thing. It should load the same procedure, respect the same safety boundaries, and produce the same kind of output.

In Hermes, quick commands can be either aliases or exec commands.

An alias still goes through the agent:

```yaml
quick_commands:
  promote:
    type: alias
    target: /background Use the Approved Promotion Execution workflow from /home/ubuntu/study/hermes-workflows/approved-promotion-execution.md. Execute the promotion note or description provided after this command, respect safety levels, and ask before external side effects.
```

That is right for work that still needs judgment.

An exec command bypasses the LLM and runs a shell command directly:

```yaml
quick_commands:
  provider_usage:
    type: exec
    command: python3 /home/ubuntu/.hermes/scripts/hermes_workflows.py provider-usage

  session_recipes:
    type: exec
    command: python3 /home/ubuntu/.hermes/scripts/hermes_workflows.py session-recipes

  hermes_sec:
    type: exec
    command: python3 /home/ubuntu/.hermes/scripts/hermes_security_watchdog.py
```

That is right for deterministic checks. No judgment required, no token spend, no waiting for the model to summarize a command it could have just run.

There are limits. Hermes quick exec commands have a short timeout. They do not accept arbitrary command arguments in the same way a shell script does. They run with a sanitized environment, which is good for safety but means credential-dependent scripts may fail if they relied on inherited secrets.

Those limits are useful. They force the question: is this really a quick command, or is it an agent workflow, a proper CLI, or a background job?

## The pyramid

I keep thinking about this as a pyramid.

```text
             natural language + LLM
        flexible, expensive, judgment-heavy

             workflow document / skill
        repeatable procedure, still agent-led

             slash command
        one-line invocation, lower friction

             Python / Bash script
        deterministic, testable, cheap

             API / service
        stable interface, composable from elsewhere

             cron / webhook / batch job
        automatic, scheduled, boring by design
```

The top is flexible. The bottom is reliable.

The top is good when the question is unclear. The bottom is good when the answer should be the same every time.

The top costs tokens. The bottom costs engineering time.

The top can make judgment calls. The bottom can be tested, monitored, logged, and called without asking a model to think.

Most AI automation problems are really placement problems. We put too much deterministic work in the LLM because it is convenient. Then we complain that it is slow, expensive, or inconsistent.

The better pattern is to let the LLM explore, then promote the stable parts down.

## A small comparison

| Layer | Best for | Good part | Bad part |
|---|---|---|---|
| Natural language + LLM | New or ambiguous work | Flexible, adaptive, can use judgment | Slow, costly, non-deterministic |
| Workflow doc / skill | Repeated but evolving work | Captures intent and pitfalls | Still consumes context and model time |
| Slash command alias | Common agent workflows | One-line invocation, works from chat | Can hide assumptions if named badly |
| Slash command exec | Fast deterministic checks | Zero-token execution, direct output | Timeout, limited args, sanitized environment |
| Python / Bash script | Known command sequences | Cheap, testable, auditable | Less flexible when assumptions change |
| API | Shared capability | Composable and observable | More engineering overhead |
| Cron / batch | Predictable maintenance | Runs without decision friction | Bad fit for urgent or judgment-heavy work |

The important distinction is not "AI versus automation." It is judgment versus determinism.

If the work needs judgment, keep the agent in the loop. If the work is deterministic, do not pay the model to rediscover it.

## What I would promote

In my Hermes setup, the obvious command candidates were the boring ones.

Provider usage checks are a good example. I do not need an LLM to remember the exact combination of commands that shows auth state, fallback order, and recent usage. I want one command:

```text
/provider_usage
```

Session recipe extraction is another one. I have a script that scans Hermes session history and writes a compact report of reusable workflow candidates. The agent may later read that report and decide what to promote, but generating the report itself is deterministic:

```text
/session_recipes
```

The local security watchdog is similar. It checks the Hermes setup for risky configuration, cron jobs without tool restrictions, and uncommitted setup changes. That is exactly the kind of thing I want as a cheap command:

```text
/hermes_sec
```

Then there are agentic commands. These should stay as aliases that call the LLM with a known procedure:

```text
/capture_review
/action_loop /home/ubuntu/study/voice-notes/some-note.md
/promote /home/ubuntu/study/hermes-promotions/some-promotion.md
```

Those commands are not trying to remove the LLM. They are trying to remove the repeated prompt.

## What I would not promote

The more useful part of the review was the list of things not to convert.

For example, QMD embeddings should stay on a scheduled and batched cadence.

Embedding is expensive relative to a quick status check. It uses CPU. It can take longer than a chat command timeout. It also benefits from batching because the right unit of work is usually "process the changed documents since the last run," not "do this immediately because I typed a command on my phone."

So the split is:

```text
capture note now
  -> save Markdown immediately
  -> make it searchable by keyword soon
  -> embed on scheduled/batched cadence
```

That keeps capture fast and keeps the heavier indexing work predictable.

Production deploys are another case. I do want commands for preflight and verification. I do not want a casual `/deploy` that can trigger production from muscle memory.

The safer shape is:

```text
/rex_preflight branch-name
  -> inspect branch, PR, SHA, build config
  -> report readiness
  -> do not deploy

explicit confirmation
  -> guarded deploy helper with expected SHA
  -> logs and rollout verification
```

Promotion should not mean bypassing safety. Sometimes promotion means giving the safe part a shortcut and making the dangerous part more explicit.

## A checklist for promotion

I would promote a workflow when most of these are true:

- I have asked for it more than twice.
- The input shape is stable.
- The output shape is stable.
- The task has a clear success or failure condition.
- The safety boundary is understood.
- It saves tokens or prevents repeated context loading.
- It is useful from a phone or messaging app.
- It can be verified quickly.

I would avoid promoting it when:

- I am still discovering what the task is.
- It needs fresh judgment at every step and has no stable skeleton.
- It is destructive or externally visible.
- It depends on secrets in ways I have not made explicit.
- It is long-running and belongs in batch processing.
- The command name would make it too easy to do the wrong thing.

That last one matters more than it sounds. A command is an affordance. If the affordance is too sharp, someone will cut themselves on it later.

## Commands as memory, but executable

There is another reason I like this pattern: commands become a kind of executable memory.

A written memory says:

```text
Provider usage checks combine auth status, fallback order, and recent usage.
```

A workflow says:

```text
When checking provider usage, run these checks and summarize the result.
```

A command says:

```text
/provider_usage
```

The command is easier to remember and harder to misapply. It does not depend on the agent loading the right old conversation. It does not depend on me typing the right incantation. It is just there.

That is the part I think many AI agent setups are missing. They accumulate good conversations, but they do not always promote the useful residue into something callable.

Chat history is a weak interface for repeated work.

Commands are a stronger one.

## The rule I am using

My current rule is simple:

Use natural language at the edge of uncertainty.

Use workflows when the shape repeats but still needs judgment.

Use slash commands when the workflow has a name.

Use scripts when the steps are deterministic.

Use APIs when other systems need the capability.

Use cron or webhooks when the timing should not depend on me remembering to ask.

That is not a strict maturity model. Things can move up and down. A script can become a workflow again if the environment changes. A command can be retired if it stops earning its place.

But it gives me a useful pressure: do not leave repeated work at the most expensive layer just because chat made it easy to start there.

The LLM is good at judgment. It is bad as muscle memory.

Promote the muscle memory.
