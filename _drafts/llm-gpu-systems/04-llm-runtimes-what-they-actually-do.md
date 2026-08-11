---
layout: post
title: "Ollama, llama.cpp, vLLM, and TensorRT-LLM"
date: 2026-08-11 09:00:00 +0000
categories: LLM inference runtimes learning
series: "Learning LLM Systems from GPU Hardware to MCP"
series_order: 4
status: draft
---

# Ollama, llama.cpp, vLLM, and TensorRT-LLM

An inference runtime is the machinery that turns model weights and a request into tokens. It chooses kernels, manages memory, schedules work, handles tokenization and sampling, and exposes an interface to applications.

The tools in this space overlap, but they optimize for different jobs.

## Ollama

Ollama is a convenient local packaging and serving layer. It makes model acquisition, local invocation, configuration, and a simple API approachable. It is an excellent first runtime for learning the operational shape of local inference.

The abstraction is useful, but it hides details that matter for deeper study: backend selection, quantization format, memory placement, batching, context limits, and device utilization.

## llama.cpp

llama.cpp is a portable inference implementation with a strong CPU and consumer-device orientation. Its GGUF ecosystem makes quantized model distribution practical across different backends. It is a good place to inspect model loading, quantization, sampling, KV-cache behavior, and backend choices more directly.

## PyTorch

PyTorch is a general ML framework, not only an inference server. It gives you tensor operations, autograd, device management, compilation, and access to GPU libraries. It is ideal for understanding and modifying model graphs, but a production serving path may need additional scheduling and memory-management machinery.

## vLLM

vLLM focuses on serving many requests efficiently. Continuous batching and specialized KV-cache management are central ideas. Instead of treating each request as a completely separate execution, the server schedules sequences together to keep the GPU busy while respecting memory limits.

## TensorRT-LLM

TensorRT-LLM is an NVIDIA-oriented optimization and serving stack. It can build optimized engines and use specialized kernels, quantization, and parallelism. The trade-off is more compilation/engine complexity and stronger dependence on the target hardware/software environment.

## How to compare them

Do not compare tools using only a single tokens-per-second number. Use the same model family, quantization, prompt set, output length, context, batch/concurrency, hardware, driver, and warmup policy.

Record:

```text
runtime and version
model/checkpoint and quantization
hardware and memory
context length and concurrency
time to first token
prefill rate
decode rate
peak memory
quality or failure differences
operational complexity
```

## A practical sequence

1. Run a small model with Ollama on the local CPU.
2. Run an equivalent GGUF workload with llama.cpp.
3. Inspect logs and model metadata.
4. Repeat on a disposable GPU host.
5. Run the same model through a serving runtime with concurrent requests.
6. Explain every performance difference as a hypothesis about compute, memory, scheduling, or transfer.

## What to remember

- A model is not a runtime.
- A runtime is not an agent.
- Convenience, portability, throughput, optimization depth, and operational complexity trade off against each other.
- Benchmarking is an experiment design problem before it is a command-line problem.

## Notebook questions

- What does Ollama simplify for a beginner?
- Which layer would you inspect if the model fits but concurrency collapses?
- Why might a server runtime outperform a local runner with the same weights?
- Which results would justify choosing portability over peak throughput?

## Bridge to the next lesson

The final lesson moves above inference. It explains where agents and MCP fit—and why exposing a powerful local runtime as a tool creates a security boundary that must be designed deliberately.
