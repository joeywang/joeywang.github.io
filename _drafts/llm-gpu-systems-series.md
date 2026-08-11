---
layout: page
title: "Learning LLM Systems from GPU Hardware to MCP"
description: "A practical study series that follows an LLM from GPU hardware and memory movement through inference runtimes, agents, and MCP."
---

# Learning LLM Systems from GPU Hardware to MCP

An LLM is not just a model file and it is not just a chat window. It is a stack:

```text
GPU hardware → kernels → tensor libraries → ML framework → inference runtime
→ agent loop → tools and MCP → application
```

This series follows that stack from the metal upward. The goal is not to memorize vendor terminology. The goal is to build a mental model strong enough to answer practical questions:

- Why did this model become slow when the context grew?
- Is the bottleneck compute, memory, synchronization, or data transfer?
- What is Ollama actually doing for me?
- Why do vLLM and llama.cpp make different trade-offs?
- Where does MCP fit, and where does it not fit?
- Which parts belong in a GPU runtime, and which parts belong in an agent harness?

## Series map

1. [The GPU is a data-movement machine](01-the-gpu-is-a-data-movement-machine.md)
2. [From threads to kernels](02-from-threads-to-kernels.md)
3. [What happens during one transformer token](03-what-happens-during-one-transformer-token.md)
4. [Ollama, llama.cpp, vLLM, and TensorRT-LLM](04-llm-runtimes-what-they-actually-do.md)
5. [MCP is not a GPU runtime](05-mcp-is-not-a-gpu-runtime.md)

## How to use the series

Read one lesson per week. Reproduce the small CPU experiments first. Move to CUDA, HIP, Metal, or GPU profiling only on disposable hardware or a cloud GPU where the toolchain is available.

Each lesson ends with:

- a mental model;
- a small experiment;
- questions to answer in your study notebook;
- a bridge to the next layer.

The series is part of a broader 24-week study plan covering GPU architecture, kernels, profiling, transformer inference, runtimes, distributed systems, agents, and MCP.
