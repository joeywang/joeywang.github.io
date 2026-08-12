---
layout: page
title: AI & Agents
permalink: /ai-agents/
description: Practical articles about AI applications, coding agents, local models, context, tools, and reliable workflows.
---

# AI & Agents

A practical reading path through the engineering around modern AI systems.

These articles focus less on model hype and more on the surrounding system: context, tools, agent loops, local models, verification, security, and the workflows that make AI useful in real work.

## Start with the foundations

1. [LLM Strengths and Limitations: A Practical Framework](/posts/llm-strengths-and-limitations-framework/)
   Understand what language models are good at, where they fail, and how to design around those limits.

2. [AI Application Architecture: LLM + Memory + Tools](/posts/ai-application-architecture-llm-memory-tools/)
   See why a useful AI application needs more than a model and a prompt.

3. [MCP, Skills, Agents, Rulesets, and Hooks](/posts/mcp-skills-agents-rulesets-hooks/)
   A map of the components that make up a governed AI development environment.

## Understand coding agents

4. [How an LLM Coding Agent Actually Builds Software](/posts/llm-agent-building/)
   The model, context builder, tool runtime, agent loop, and verification layer explained from the inside.

5. [Giving Hermes Durable Codebase Context with GitNexus, LSP, and AGENTS.md](/posts/durable-codebase-context-hermes-gitnexus-lsp/)
   How different kinds of codebase knowledge can have different owners instead of forcing grep to do everything.

6. [The Hard Part of AI PR Review Is Not Reading the Diff](/posts/ai-pr-review-open-code-review/)
   Why review agents need evidence, repository context, and a bias-resistant verification loop.

## Build with local models and safer workflows

7. [Using LM Studio and Gemma as a Local Engine for Coding Agents](/posts/lm-studio-gemma4/)
   A local-model setup for experimenting with coding-agent workflows.

8. [Orchestrating Hermes with Local Gemma](/posts/orchestrating-hermes-with-local-gemma/)
   Cheap routing, delegation, explicit boundaries, and safe Rails workflows.

9. [Golden Rules for Cheaper, Safer LLM Agents](/posts/golden-rules-for-cheaper-safer-llm-agents/)
   When to use an LLM, a workflow, a script, a command, or a scheduled job.

10. [Don't Leave Good AI Workflows in Chat](/posts/promoting-ai-workflows-into-commands/)
    A practical pattern for promoting repeated work into cheaper and more reliable layers.

## Continue exploring

- [All AI articles](/categories/ai/)
- [All engineering articles](/categories/engineering/)
- [Subscribe via RSS](/feed.xml)

This page will evolve as new articles add tested patterns, implementation notes, and lessons from real systems.
