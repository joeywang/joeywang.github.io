---
layout: post
title: "The GPU Is a Data-Movement Machine"
date: 2026-08-11 09:00:00 +0000
categories: GPU LLM systems learning
series: "Learning LLM Systems from GPU Hardware to MCP"
series_order: 1
status: draft
---

# The GPU Is a Data-Movement Machine

When people explain a GPU, they usually start with arithmetic: thousands of cores, tensor units, and astonishing FLOPS. That is useful marketing, but it is not the best first mental model.

A better starting point is this:

> A GPU is a machine for moving large amounts of data to many arithmetic units at the same time.

The arithmetic matters. The movement often decides whether the arithmetic is useful.

## The hierarchy

A modern accelerator has several kinds of storage:

```text
registers       tiny, private, fastest
shared/local    small, coordinated within a workgroup
L1/L2 cache     hardware-managed reuse
VRAM/HBM        large, high-bandwidth device memory
system RAM      larger, slower from the GPU's perspective
storage/network persistent, much slower again
```

The closer storage is to the arithmetic unit, the smaller and faster it tends to be. A kernel that repeatedly fetches the same value from far-away memory can waste most of its theoretical compute capacity waiting.

## Why LLMs care

A transformer performs huge matrix multiplications. The same weights are reused across many input values, which is good for a GPU. But decoding one token at a time creates a different pattern: the runtime repeatedly reads model weights and the growing key/value cache while doing relatively little new computation.

That is why *prefill* and *decode* behave differently:

- **Prefill** processes a prompt in larger parallel batches. It often has abundant arithmetic work.
- **Decode** generates one token at a time. It can become limited by memory movement, launch overhead, and cache behavior.

The same model can therefore look fast during prompt ingestion and slow during generation.

## Compute versus bandwidth

Suppose a kernel performs many floating-point operations for every byte loaded. It may be compute-bound: adding more arithmetic throughput could help. If it performs few operations per byte, it may be memory-bandwidth-bound: faster arithmetic units will not help until data movement improves.

This is the beginning of roofline reasoning. Do not ask only, “How many FLOPS does this GPU have?” Ask:

1. How many bytes must the workload move?
2. How much arithmetic is done per byte?
3. Which memory level supplies those bytes?
4. Is the host waiting on a device transfer or kernel launch?

## A CPU experiment first

You can learn the pattern without a GPU. Write two matrix multiplication implementations:

1. a straightforward triple loop;
2. a tiled version that reuses blocks of the input matrices in a smaller working set.

Measure the same matrices repeatedly after warmup. The tiled version is not magically doing less mathematics. It is arranging the same mathematics so the cache can reuse data.

The lesson transfers to GPUs: good kernels are often careful choreography of data reuse, parallel work, and synchronization.

## What to remember

- Hardware diagrams are really latency and bandwidth diagrams.
- Arithmetic throughput is valuable only when data arrives fast enough.
- Prefill and decode stress different parts of the machine.
- Model size is not the same as runtime memory pressure; KV cache, workspace, batching, and temporary buffers matter.
- Measure movement and waiting, not just arithmetic.

## Notebook questions

- What is the difference between capacity, bandwidth, and latency?
- Why might a larger batch improve throughput but hurt latency?
- Which values in transformer inference are reused, and which are newly produced?
- What would happen if the model did not fit in VRAM?

## Bridge to the next lesson

The next layer is the programming model: how a developer expresses thousands of pieces of work, how those pieces are grouped, and how they cooperate without destroying the performance gained from parallelism.
