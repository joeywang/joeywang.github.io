---
layout: post
title:  "Token Efficiency for AI Coding Agents in 2026"
description: "Six practical techniques for cutting token spend in AI coding agents, from skeleton indexes to symbol-level retrieval and semantic caching."
date:   2026-04-07 10:00:00 +0000
categories: [AI]
tags: [ai, llm, agents, performance]
---

<audio controls preload="metadata" src="/assets/audio/token-saving-summary.ogg">
  Your browser does not support the audio element.
</audio>

The bottleneck for AI coding in 2026 isn't model intelligence, it's what I'd call the context tax. Agents like Claude Code and Codex become more autonomous by default, which means they also tend to over-read the codebase: listing directories, catting files, and re-discovering things they already saw two turns ago. That habit shows up directly on the bill. Here's how I architect a workflow to keep it down.

## 1. Input: send blueprints, not files

The idea is to stop sending files and start sending a map. Tools like `ai-codex` or RepoMix generate a high-density index file that orients the agent before it starts reading.

That prevents the agent from running `ls -R` or `cat`-ing fifty files just to find one variable, which is a real savings on discovery tokens. The tradeoff is that a stale index can send the agent chasing file paths that no longer exist. Regenerate the skeleton after every major refactor, and open sessions with something like: "Read index.md first, don't search files until I give you a specific task."

## 2. Output: cut the preamble

Every "Sure, I'd be happy to help!" is a token you paid for. Plugins like [Caveman](https://github.com/juliusbrussee/caveman), or a plain telegraphic system prompt, cut output tokens by something like 40-70% and lower latency along with it. The tradeoff is that heavily compressed output can feel cold, and aggressive compression occasionally drops nuance from complex answers. In practice: add `Output: telegraphic, fragments only, no preamble` to your rules and see how the agent responds before relying on it for anything subtle.

## 3. Command output: compact before it hits the transcript

Two thousand lines of "test passed" logs flooding the chat history is pure waste. A compaction layer (something like [RTK](https://github.com/rtk-ai/rtk), or a similar "distill" tool) turns a huge stack trace or `npm install` log into a three-line summary, which keeps the conversation usable for longer.

The risk is blindness: if a minor warning buried in that log was actually the root cause, compression can hide it. Use compaction by default, but run a raw command once if the agent seems stuck.

## 4. Locating code: retrieve by symbol, not by file

Don't read the haystack to find the needle. AST-based tools (Serena via LSP, or similar indexers) let the agent fetch one function instead of a whole file, which is a large saving on large files. The cost is a Language Server running in the background, which is one more thing that can be misconfigured. For big legacy codebases, favor "get symbol" tools over "read file" tools wherever the harness supports it.

## 5. MCP as a middleware layer

An MCP server sitting between the agent and the model can intercept and optimize what actually gets counted as input. One pattern turns the project into a knowledge graph so the agent queries the graph (cheap) instead of scanning files (expensive). Another strips comments and whitespace before tokens are counted. The setup cost is real, mostly configuration overhead, but for a codebase big enough to need graph-based navigation, it pays for itself quickly.

## 6. Shrinking context: compact and forget on purpose

The `/compact` command, or manual session layering, flushes the parts of the conversation that are no longer relevant. That's most useful when combined with a simple habit: commit your working code before you compact, because if you haven't, the agent can lose track of the actual state of the repo once the older turns are gone. Treat the chat history like a `tmp` folder: useful while you need it, safe to clear once you don't.

## What this adds up to

Combine a skeleton index for orientation, symbol-level retrieval for locating code, output compaction for logs, and a muzzled response style, and the difference isn't just cost. It's model quality. Every log line, politeness token, and redundant import you feed the model competes with the actual problem for its attention. A lean context is a sharper context, not just a cheaper one.
</content>
