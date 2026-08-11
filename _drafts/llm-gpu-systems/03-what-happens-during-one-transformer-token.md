---
layout: post
title: "What Happens During One Transformer Token"
date: 2026-08-11 09:00:00 +0000
categories: LLM transformers inference learning
series: "Learning LLM Systems from GPU Hardware to MCP"
series_order: 3
status: draft
---

# What Happens During One Transformer Token

An LLM does not retrieve a finished sentence from a database. During generation, it repeatedly runs a forward pass, turns the result into a probability distribution, samples or selects a token, and feeds that token back into the next step.

## The two phases

### Prefill

The prompt is known all at once. The runtime processes many token positions in parallel, computes attention, and builds the key/value cache. This phase often benefits from large matrix operations and high parallelism.

### Decode

After the prompt, generation usually advances one token at a time. Each new token passes through the model while reusing cached keys and values from previous positions. The workload is smaller per step, but it repeats many times and reads a large amount of model state.

## One layer

A simplified decoder layer looks like:

```text
input residual
    ↓
normalization
    ↓
query/key/value projections
    ↓
attention against current + cached keys/values
    ↓
output projection
    ↓
residual addition
    ↓
normalization
    ↓
MLP / gated feed-forward network
    ↓
residual addition
```

Real architectures vary. Some use grouped-query attention, rotary position embeddings, different normalization placements, mixture-of-experts routing, or sliding-window attention. The important idea is that the model is a sequence of tensor transformations with large reusable weight matrices.

## KV cache memory

For each layer, the runtime keeps keys and values for prior positions. A rough memory model is:

```text
cache bytes ≈ layers × 2 × sequence length × KV heads × head dimension × bytes per element × batch
```

The exact layout and compression vary, but the trend is universal: longer context, more layers, more concurrent sequences, or wider heads require more memory.

This is why serving systems treat KV cache as a scheduling resource. A runtime may have enough room for the weights but not enough room for the requested context and concurrent users.

## From hidden state to a token

After the final layer, the model produces logits over the vocabulary. Sampling applies temperature, top-k/top-p or other constraints, then selects the next token. The tokenizer maps token IDs back into text. The runtime repeats until a stop condition.

The visible answer is therefore the final product of:

- tokenization;
- repeated tensor execution;
- memory and cache management;
- numeric precision and quantization;
- sampling policy;
- stop rules and streaming.

## Why “tokens per second” is incomplete

A benchmark should separate:

- time to first token;
- prompt processing speed;
- decode tokens per second;
- total latency;
- peak memory;
- concurrency;
- output quality and determinism.

A runtime can improve throughput while making one interactive request feel slower. A quantized model can fit in memory while producing a quality change that matters for a task. A larger context can avoid truncation while reducing concurrency.

## What to remember

- Prefill and decode are different workloads.
- KV cache is a major memory and scheduling concern.
- Sampling and tokenization are part of the user-visible runtime, not decorations around the model.
- Runtime benchmarks need workload context.

## Notebook questions

- Which operations happen once per prompt and which repeat per generated token?
- How would KV cache change with four simultaneous conversations?
- What does quantization reduce: weights, activations, cache, or all of them?
- Why might a smaller model with a longer context be slower than expected?

## Bridge to the next lesson

The next lesson compares the systems that package and execute these operations: Ollama, llama.cpp, PyTorch, vLLM, and TensorRT-LLM.
