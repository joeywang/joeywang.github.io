---
layout: post
title: "MCP Is Not a GPU Runtime"
date: 2026-08-11 09:00:00 +0000
categories: MCP agents security learning
series: "Learning LLM Systems from GPU Hardware to MCP"
series_order: 5
status: draft
---

# MCP Is Not a GPU Runtime

It is easy to place every AI technology into one blurry category. GPU kernels, Ollama, agents, and MCP are not interchangeable layers.

A useful separation is:

```text
GPU kernel       performs parallel numeric work
inference runtime executes model graphs and produces tokens
agent loop       decides what to do next
MCP              standardizes how tools/resources are exposed
approval system  decides which side effects are allowed
observability    records what happened and why
```

## The model runtime boundary

A model runtime answers questions such as:

- How are weights loaded?
- Which device executes the tensors?
- Which kernels implement attention and matrix multiplication?
- How is KV cache allocated?
- How are requests batched?
- How are tokens sampled and streamed?

MCP does not answer these questions. It can expose a model-backed capability to another application, but the model still runs in a runtime underneath.

## The agent boundary

An agent loop receives a goal, builds context, asks a model for a next action, invokes a tool, observes the result, and continues. A strong agent harness makes the action boundary explicit rather than hiding arbitrary host access behind a prompt.

MCP can describe tools and carry calls/results. That is valuable interoperability, but a tool schema is not permission by itself. The host still needs allowlists, authentication, approvals, sandboxing, timeouts, output limits, and audit records.

## A safe local example

Imagine exposing a benchmark-history tool:

```text
get_benchmark_run(run_id)
```

A safe version would:

- allow only known run IDs;
- read from a fixed directory;
- return bounded structured data;
- never execute a shell command;
- redact environment variables and paths;
- record caller, time, and run ID.

An unsafe version might expose:

```text
execute(command)
```

with the same host identity as the model runtime. That turns a convenient tool into a privilege boundary. If it is ever necessary, it needs explicit approvals and a sandbox—not a more persuasive prompt.

## Where GPU work appears

An MCP tool might call an inference server. The chain could be:

```text
agent → MCP client → benchmark tool → inference API → runtime → GPU kernels
```

The MCP layer adds transport and capability semantics. The runtime handles tensors. The GPU executes kernels. Observability should make the chain visible so a slow answer can be attributed to queueing, network transport, model prefill, decode, tool execution, or human approval.

## What to remember

- MCP is an integration protocol, not an acceleration technology.
- A tool description does not grant safe permission.
- Local inference and local tools amplify both capability and blast radius.
- The safest learning project is read-only and bounded.

## Notebook questions

- Which layer owns model memory?
- Which layer owns user approval?
- What information should a benchmark tool never return?
- How would you trace one slow agent response across MCP and inference?

## Final series exercise

Build a read-only MCP tool that returns benchmark metadata from a local model run. Connect it to an agent only after the standalone benchmark works. Add an allowlist, timeout, bounded output, redaction, and an execution trace. The goal is to understand the entire stack without giving an agent an unrestricted shell.
