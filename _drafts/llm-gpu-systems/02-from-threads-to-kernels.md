---
layout: post
title: "From Threads to Kernels"
date: 2026-08-11 09:00:00 +0000
categories: GPU kernels CUDA learning
series: "Learning LLM Systems from GPU Hardware to MCP"
series_order: 2
status: draft
---

# From Threads to Kernels

A GPU kernel is a function designed to run many times in parallel. The important question is not “How do I write a loop on the GPU?” It is “How do I divide work so thousands of workers can progress while sharing data safely?”

## The common model

CUDA calls the hierarchy grids, blocks, and threads. HIP uses similar concepts. Metal uses grids, threadgroups, and threads. The names differ, but the questions are alike:

- Which worker owns this element?
- Which workers cooperate on a tile?
- When is shared data ready?
- Are neighboring workers reading neighboring addresses?
- What happens when a branch makes workers take different paths?

## A vector-add kernel

For an output element `c[i] = a[i] + b[i]`, each worker can own one index. The worker calculates its global index, checks that it is inside the array, loads two values, adds them, and stores one result.

There is almost no need for coordination. That makes vector addition a useful first kernel, but it is not representative of the hardest LLM operations.

## Tiled matrix multiplication

Matrix multiplication is more interesting because each output value uses a row and a column. A naive implementation repeatedly fetches values from device memory. A tiled implementation loads small blocks into shared memory, synchronizes the workgroup, reuses the blocks for many output values, then moves to the next tile.

The synchronization is necessary. A worker must not read a shared-memory value before the other workers have finished writing it. But synchronization also has a cost, and excessive coordination can erase the benefit of parallelism.

## The performance traps

### Uncoalesced access

If neighboring workers access scattered memory locations, the hardware cannot combine their requests efficiently. A mathematically correct kernel can be slow because its access pattern fights the memory system.

### Divergence

Workers execute in groups. If some take one branch and others take another, the group may execute both paths with some workers inactive during each path.

### Register pressure

Registers are fast, but limited. A kernel that needs too many registers can reduce the number of active groups or spill values into slower memory.

### Launch overhead

A tiny kernel can spend a significant fraction of its time being launched. This is one reason fusion—combining several operations into one kernel—can help.

## A safe learning sequence

1. Implement vector add.
2. Implement a reduction and learn synchronization/atomics.
3. Implement tiled matrix multiplication.
4. Change the memory access pattern intentionally and measure the damage.
5. Compare separate operations with a fused operation.
6. Profile rather than guessing.

Start on a disposable GPU environment. On a CPU, use the same exercises to learn locality, tiling, and measurement, but do not assume CPU and GPU timings have the same causes.

## What to remember

- A kernel is a data-parallel work decomposition, not just a function with a special decorator.
- Correctness comes before occupancy or cleverness.
- Memory access, divergence, synchronization, and launch overhead are first-class costs.
- CUDA, HIP, and Metal differ in API, but the underlying performance questions transfer.

## Notebook questions

- Which data does each worker own?
- Which data is reused by a group?
- Where must synchronization happen?
- What is the smallest change that would make the access pattern worse?
- Which profiler counter would confirm your hypothesis?

## Bridge to the next lesson

Now we can follow a transformer token. The next article connects matrix multiplication, attention, normalization, KV cache, and sampling into one execution story.
