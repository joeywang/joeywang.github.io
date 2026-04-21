---
layout: post
title: "LM Studio Local Agent Runbook: Pi and OpenCode Step by Step"
date: 2026-04-21
author: "Joey Wang"
description: "A step-by-step runbook for using LM Studio as a local OpenAI-compatible backend for Pi agents and OpenCode, including config examples, verification steps, and troubleshooting."
tags: [ai, llm, gemma, lm-studio, agents, pi, opencode, local-llm]
categories: [AI, Engineering]
---

# LM Studio Local Agent Runbook: Pi and OpenCode Step by Step

This is the setup guide I wanted while I was trying to make LM Studio work as a local engine for coding agents.

The goal here is not theory. The goal is to get a model running locally, expose it through LM Studio's OpenAI-compatible endpoint, wire it into Pi or OpenCode, and verify that the whole stack is alive before you waste time debugging the wrong thing.

If you want the broader context on why I was doing this and where the setup still falls short, read the companion article:

[Using LM Studio and Gemma as a Local Engine for Coding Agents]({% post_url 2026-04-13-lm-studio-gemma4 %})

## What you are building

The target architecture is simple:

1. LM Studio runs the model locally.
2. LM Studio exposes `http://127.0.0.1:1234/v1`.
3. Pi agents or OpenCode point at that endpoint.
4. Your agent harness uses LM Studio as if it were an OpenAI-compatible backend.

That does not give you a perfect local agent. It gives you a local model backend that your agent can talk to.

## Prerequisites

Before you start, make sure you have:

- LM Studio installed
- at least one model downloaded in LM Studio
- a model that actually fits your machine
- Pi or OpenCode available locally if you want to test integration immediately

One practical warning up front: model selection is constrained by memory much faster than people expect.

For example, I hit memory trouble when pushing into Qwen 35B-class MLX setups. Bigger is not automatically better if the runtime becomes unstable or dies during actual agent work.

## Step 1: start LM Studio and load a model

Open LM Studio and load the model you want to serve.

My actual workflow is:

1. Open LM Studio.
2. Download or select the model.
3. Open the Developer or Local Server section.
4. Start the local server.
5. Confirm it is listening on `http://127.0.0.1:1234/v1`.

The important detail is that you are not just chatting in the LM Studio UI. You are turning it into a local API server.

## Step 2: sanity-check the local endpoint

Before configuring any agent client, make sure the LM Studio endpoint responds.

Run:

```bash
curl http://127.0.0.1:1234/v1/models
```

If that works, you should get a model list back.

If it does not work, stop there and fix the server first. Do not start editing Pi or OpenCode config until this responds.

## Step 3: change the LM Studio settings that matter

These are the first settings I would touch before trying agent workloads.

### Disable Unified KV Cache

This helped the most when I was seeing prompt stalls or weird runtime behavior.

If you see large prompts stuck at 0%, this is one of the first things I would change.

### Set context length manually

Do not leave context length on auto if you want more predictable behavior.

Choose an explicit number based on your machine and the kind of tasks you are running.

### Add stop tokens if Gemma leaks think tags

Gemma can leak reasoning markers into visible output. That is annoying in normal chat and actively bad in agent loops.

If you are seeing leaked thought markers, add stop tokens early instead of pretending this will sort itself out later.

## Step 4: wire LM Studio into `~/.pi/agents/models.json`

If you are using Pi-style agents, this is the general shape:

```json
{
  "providers": {
    "lm-studio": {
      "id": "local-lm-studio",
      "name": "LM Studio",
      "api": "openai-completions",
      "compatibility": "legacy-system-role",
      "apiKey": "ollama",
      "baseUrl": "http://127.0.0.1:1234/v1",
      "models": [
        {
          "id": "qwen3.5-9b-sushi-coder-rl-mlx",
          "_launch": true,
          "name": "qwen 3.5 sushi coder",
          "contextWindow": 84000,
          "input": ["text"],
          "reasoning": true
        },
        {
          "id": "gemma-4-e4b-it-mlx",
          "_launch": true,
          "name": "Gemma 4 E4B",
          "contextWindow": 84000,
          "input": ["text"],
          "reasoning": true
        }
      ]
    }
  }
}
```

Things worth paying attention to:

- `baseUrl` should point at the LM Studio endpoint
- `apiKey` is usually just a placeholder for local use
- `compatibility` can matter if the client is picky about role handling
- `reasoning: true` is only useful if your harness can handle reasoning output cleanly

That last point is not academic. If the harness does not know what to do with reasoning output, turning it on can make the whole setup noisier instead of smarter.

## Step 5: wire LM Studio into OpenCode

For OpenCode, the provider block is usually simpler:

```json
{
  "lm-studio": {
    "models": {
      "gemma-4-26b-a4b-it-mlx": {
        "_launch": true,
        "name": "Gemma 4 26B A4B IT MLX"
      }
    },
    "name": "LM Studio",
    "npm": "@ai-sdk/openai-compatible",
    "options": {
      "baseURL": "http://127.0.0.1:1234/v1"
    }
  }
}
```

The important part is not the shape of the JSON. The important part is that OpenCode is treating LM Studio like an OpenAI-compatible backend.

That is what makes this setup useful for experimentation. You can swap the model backend without rewriting the rest of the agent harness.

## Step 6: verify with a cheap test before a real agent task

Do not jump straight into a huge repository review.

Do these first:

1. Confirm the client can see the configured model.
2. Send one short plain-text prompt.
3. Try one tiny bounded task, like summarizing a short file or reviewing a tiny diff.

You want to prove the stack works in the smallest possible way before turning the task size up.

## Step 7: simplify the Pi prompt before blaming the model

This matters more for local models than for stronger cloud models.

If Pi is dragging around a huge system prompt, a giant skill catalog, MCP server descriptions, tool docs, and every meta-instruction imaginable, you are burning context before the real work even starts.

If you are struggling with context pressure, simplify aggressively:

- remove skills that are not needed
- avoid loading MCP descriptions the task will not use
- shorten the system prompt
- keep the operational rules direct

You are not trying to make the agent less capable. You are trying to stop wasting the context window on scaffolding.

## Step 8: know the problems you are likely to hit

This is the part that usually gets skipped. It should not be skipped.

### Problem: Qwen 35B on MLX runs out of memory

This is a machine constraint problem, not a prompting problem.

If the model is too large for the actual workflow, move down to something that stays alive under repeated turns.

### Problem: KV cache support on LM Studio + MLX is incomplete

This showed up for me as runtime weirdness and failed expectations around caching.

I would not assume KV-related optimizations are fully reliable just because they exist in a settings panel.

### Problem: broken KV cache state causes 0% prompt stalls

If the prompt sits at 0%, I would treat runtime cache state as suspicious immediately.

My default response is:

1. stop the run
2. disable Unified KV Cache
3. retry with a much smaller prompt
4. verify the model is healthy again before doing anything larger

### Problem: Gemma leaks think tags

This is real and it matters.

In an agent loop, think-tag leakage can break parsing, pollute tool output, and waste context.

### Problem: Gemma shared KV is not something I would rely on here

For the LM Studio runtime I was testing, shared KV for Gemma was not something I could treat as usable.

If that is part of your mental model for why the setup should be fast or stable, remove that assumption first.

## Concrete error text worth recognizing

One runtime error I hit looked like this:

```text
Error: Error in iterating prediction stream:
NotImplementedError: RotatingKVCache Quantization NYI
```

That is useful because it tells you this is not a "maybe I should rewrite my prompt" situation.

It points to a runtime capability gap.

## Troubleshooting checklist

If the whole setup is failing, I would check things in this order:

1. Is LM Studio actually serving on `127.0.0.1:1234`?
2. Does `curl http://127.0.0.1:1234/v1/models` work?
3. Does the client model ID exactly match what LM Studio exposes?
4. Is the client expecting a different OpenAI compatibility mode than the provider config uses?
5. Is shared KV part of the setup assumptions?
6. Is Unified KV Cache making things worse?
7. Is the prompt too large before the actual task even starts?
8. Is Gemma leaking think tags into output the harness expects to parse cleanly?

That order has saved me time because it forces me to debug the runtime before I start rewriting prompts for no reason.

## What I would do first on a fresh machine

If I had to set this up again from zero, I would keep it boring:

1. Start LM Studio.
2. Load one model that fits comfortably.
3. Confirm `curl http://127.0.0.1:1234/v1/models` works.
4. Disable Unified KV Cache.
5. Set context length manually.
6. Wire one client into the endpoint.
7. Test with one tiny task.
8. Only then move to bigger prompts or more capable models.

That sounds conservative. It is also much faster than trying to brute-force your way through three problems at once.

## Final note

The biggest trap in local agent setup is mixing all the variables together.

Do not debug:

- a new model
- a large prompt
- a new harness
- a new cache setting
- and a new client config

all at the same time.

Make the stack boring first. Then make it ambitious.
