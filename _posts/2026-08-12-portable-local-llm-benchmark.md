---
layout: post
title: "A Portable Workflow for Testing Small Local LLMs on Modest Hardware"
description: "A repeatable way to download, serve, benchmark, and choose small GGUF models for Hermes and coding-agent work across different CPU and memory budgets."
date: 2026-08-12 18:00:00 +0100
author: "Joey Wang"
tags: [local-ai, llm, gguf, llama-cpp, hermes, coding-agent, benchmarking]
categories: [AI, Engineering]
---

# A Portable Workflow for Testing Small Local LLMs on Modest Hardware

<audio controls preload="metadata" src="/assets/audio/portable-local-llm-benchmark-summary.ogg">
  Your browser does not support the audio element.
</audio>

I wanted a local model that could handle routine Hermes work on a small ARM server: 12 GB of memory and two virtual CPUs. The target was not a leaderboard score. I wanted to know whether the model could follow short instructions, return JSON, write a small function, fix a bug, and produce a short plan without exhausting the machine.

The same question comes up whenever hardware changes. A model that feels good on a 16 GB Apple Silicon laptop may behave very differently on a two-core Linux VM. Rather than asking whether a model needs a fixed amount of memory, I wanted a measurement process I could repeat on the next machine.

## The setup

The server used for this test had:

```text
Architecture: aarch64
CPU:         2 x Neoverse-N1 OCPU
Memory:      11 GiB usable
Swap:        8 GiB
Runtime:     llama.cpp / llama-server
Quantization: Q4_K_M GGUF
```

The model server exposed an OpenAI-compatible endpoint on loopback:

```text
http://127.0.0.1:18080/v1
```

Binding to loopback matters. This was a local experiment, not an internet-facing inference service. An endpoint that accepts prompts and may return private code should not be exposed unnecessarily.

The llama.cpp command was deliberately simple:

```bash
llama-server \
  -m /path/to/model.gguf \
  --alias local-model \
  --host 127.0.0.1 \
  --port 18080 \
  -c 32768 \
  -t 2 \
  -np 1 \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --metrics \
  --no-webui
```

The exact flags are not universal. The important parts are the model path, loopback binding, one request slot, a context size that fits the machine, and metrics that let the test record speed rather than relying on impressions.

## Keep the model download separate from the benchmark

I use the Hugging Face CLI to download one named file into a predictable directory:

```bash
mkdir -p "$HOME/local-llm/models/Qwen3-4B-Instruct-2507-GGUF"

hf download \
  bartowski/Qwen_Qwen3-4B-Instruct-2507-GGUF \
  Qwen_Qwen3-4B-Instruct-2507-Q4_K_M.gguf \
  --local-dir "$HOME/local-llm/models/Qwen3-4B-Instruct-2507-GGUF"
```

A repeatable directory layout makes the server command portable:

```text
local-llm/
├── models/
│   └── <model-name>/
│       └── <quantization>.gguf
├── src/llama.cpp/
├── start-<model-name>.sh
└── (optional) hermes-local wrapper
```

Download only the quantization you intend to test. A model repository often contains many variants, and downloading a whole repository makes it harder to know which file was actually measured.

## Always check the runtime before loading a model

Before starting anything, record the hardware and check for an existing server:

```bash
uname -m
nproc
lscpu | grep -E 'Architecture|Model name|CPU\\(s\\)' | head
free -h
ps -eo pid,etime,%cpu,%mem,rss,cmd | grep -E 'llama-server|ollama|mlx' | grep -v grep || true
```

Then start the server and wait for its health endpoint:

```bash
./start-qwen3.sh &

until curl -fsS http://127.0.0.1:18080/health | grep -q '"status":"ok"'; do
  sleep 2
done
```

Do not treat a process that exists as a ready model. llama-server can spend a while loading weights. During that period, `/health` returns a 503 loading response. The benchmark should start only after the endpoint reports healthy.

After loading, check memory again:

```bash
ps -o pid,etime,%cpu,%mem,rss,vsz,cmd -C llama-server
free -h
```

The file size is not the memory footprint. The runtime also needs model metadata, working buffers, the KV cache, and the context window. On this machine, a 2.5 GB Q4 model used roughly 7.5 GB RSS with a 32K context.

## Test capabilities, not just speed

A useful smoke benchmark should exercise the tasks the local model is expected to do. I used seven small cases:

1. Exact instruction following
2. JSON-only structured output
3. Arithmetic
4. A small logic puzzle
5. Writing a Python function
6. Fixing an empty-list bug
7. Producing a four-step implementation plan

The test sends each case through the OpenAI-compatible chat completions endpoint with temperature zero and checks the result programmatically:

```python
payload = {
    "model": "local-model",
    "messages": [{"role": "user", "content": prompt}],
    "temperature": 0,
    "max_tokens": max_tokens,
}
```

The checks should be explicit. For example, the bug-fixing case should verify that the response contains a guard for an empty list and returns zero. A human can see that two answers are equivalent, but a script makes the result reproducible and exposes formatting differences.

The benchmark also records:

```text
wall time
prompt tokens and prompt tokens/sec
generated tokens and generation tokens/sec
model output
finish reason
errors from the checker
```

The raw output belongs beside the script. A summary without the individual responses is not enough to diagnose a failure.

## The reasoning-token trap

One of the first results looked like a very poor E2B score. Several answers were empty even though the model was clearly working. Inspecting the raw response showed that the model had filled the completion budget with `reasoning_content` and never reached a visible answer.

That is a serving and evaluation issue, not a clean measure of model capability. Small reasoning models need separate handling for:

- hidden or visible reasoning content;
- the token budget allocated to reasoning;
- the final answer budget;
- stop conditions and end-of-turn markers.

A test that only reads `message.content` can report a false failure when the useful answer is in another response field. Conversely, a model that regularly consumes its entire budget thinking is still a poor Hermes fallback if the agent runtime cannot handle that behavior reliably.

For a fair comparison, either disable extended thinking for short operational tasks or allocate enough tokens for both reasoning and the final answer. Then run the same test again.

## Results on the two-OCPU server

The first comparison included Gemma 4 E2B and E4B, followed by three smaller general or coding models. These were observed results from this machine, not claims about every runtime or quantization.

| Model | GGUF file | Raw pass rate | Bug fix | Generation speed | Peak RSS |
|---|---:|---:|---:|---:|---:|
| Gemma 4 E2B | 3.11 GB | 1/7 | Failed in this setup | 8.7 tok/s | 4.7 GB |
| Gemma 4 E4B | 4.98 GB | 4/7 | Passed | 4.7 tok/s | 7.9 GB |
| Qwen2.5-Coder 3B | 1.93 GB | 3/7 | Passed | 8.6 tok/s | about 7.2 GB |
| Phi-4-mini | 2.49 GB | 3/7 | Semantically passed, formatting failed | 5.8 tok/s | about 7.2 GB |
| Qwen3-4B-Instruct-2507 | 2.50 GB | 5/7 | Passed | 5.9 tok/s | about 7.5 GB |

The score is only one signal. Qwen2.5-Coder produced correct code but wrapped it in Markdown fences, so a strict code-only checker marked it wrong. Phi-4 calculated the right arithmetic result but was cut off before completing the response. Qwen3 returned valid JSON, passed the bug-fix and planning cases, and was the best general candidate in this run.

The same E2B family model performs differently on a 16 GB MacBook using the MLX runtime. There, E2B reached 6/7, missing only the planning case. That comparison is useful, but it does not contradict the Linux result. The machines differ in CPU, memory bandwidth, runtime, quantization format, prompt template handling, and response parsing.

## Choosing always-on versus on-demand

The decision should use both capability and resource headroom.

An always-on model must leave room for the agent runtime, the operating system, logs, Telegram or gateway processes, and temporary command output. A model that uses nearly all available memory may work in a quiet benchmark and then trigger swapping during a real coding task.

For this 12 GB class machine, I would use these practical bands:

```text
under 5 GB RSS:     plausible always-on candidate
5–7 GB RSS:         test carefully with the real agent workload
7–9 GB RSS:         prefer on-demand or reduce context
above 9 GB RSS:     unsafe for a shared host
```

These are operating guidelines, not model requirements. Context size can move a model between bands. A 16K context may be a better default than 32K when the model is handling short coding tasks.

For an on-demand workflow:

```bash
./start-qwen3.sh
# wait for /health to report status=ok
hermes chat --model local-qwen3 ...
# stop the server after the task
```

For an always-on fallback, add a supervised service only after measuring idle memory, request memory, startup behavior, and recovery from a failed request. Do not turn a benchmark command into a system service before those checks pass.

## Make the workflow portable

The reusable part is a small model manifest plus one benchmark runner. For each candidate, record:

```yaml
name: qwen3-4b-instruct-2507
source: bartowski/Qwen_Qwen3-4B-Instruct-2507-GGUF
file: Qwen_Qwen3-4B-Instruct-2507-Q4_K_M.gguf
alias: local-qwen3
context: 16384
temperature: 0
max_tokens: 256
expected_use: routine coding fallback
```

The runner should accept the model path and alias rather than embedding one model name in the test. Run candidates sequentially, not concurrently, unless the goal is specifically to measure multi-model contention. Save one JSONL file per run with the hardware summary and llama.cpp version.

Keep the following separate:

- model acquisition;
- server startup and health checks;
- capability tests;
- memory and throughput measurement;
- Hermes integration tests;
- policy for escalation.

This separation prevents a failing download, a bad chat template, and a weak model from all looking like the same problem.

## Give the local model an explicit command

Once the local server is healthy, the most useful operational improvement is a command that makes model selection explicit. Relying on the normal Hermes routing path is convenient, but it can obscure whether a task actually ran locally or went to a cloud fallback.

I added a `hermes-local` wrapper for tasks that must run on the persistent local worker:

```bash
hermes-local "Reply exactly LOCAL_OK"
```

The wrapper pins the request to the `local-qwen3` model and checks the loopback endpoint before starting Hermes. It deliberately does **not** fall back to a cloud model. If Qwen3 is unavailable, the command fails clearly instead of silently changing the execution environment.

For a bounded implementation task in an isolated worktree:

```bash
hermes-local \
  --in /path/to/isolated-worktree \
  --max-turns 20 \
  "Implement the prepared task in IMPLEMENTATION.md and run its verification command."
```

The command defaults to the `file,terminal` toolsets and no extended reasoning. Those defaults are intentional: the local model is an implementer, not the architecture owner. The cloud model should write the specification, while the local worker performs the small edit and deterministic test run.

A safe delegation contract has three parts:

1. **Cloud model:** inspect the repository and write a precise `IMPLEMENTATION.md`.
2. **Local model:** edit only named files and run the named verification command.
3. **Cloud model:** inspect the diff, repeat broader tests, and make PR, merge, or deployment decisions.

This separation makes the local model useful without pretending that a small CPU model should own ambiguous debugging, security review, architecture, or production operations.

## The test that matters after the smoke test

A seven-prompt benchmark is a filter. It is not proof that a model can run a coding agent.

The next test should use a temporary repository and ask the model to:

1. inspect the repository;
2. implement a small change;
3. add or update tests;
4. run the tests;
5. report the changed files and verification result.

The runner should capture the complete transcript, tool calls, command results, elapsed time, and final diff. It should fail if the model claims success without a real passing test command.

That test measures the agent loop as well as the model. A model can pass direct prompts and still fail when it needs to plan, call a tool, consume the result, and continue for several turns.

## What I would use

On this two-OCPU, 12 GB machine, Qwen3-4B-Instruct-2507 is the best general candidate from this small comparison. I would start it with a 16K context, keep it on-demand, and test the real Hermes implementation workflow before making it a permanent fallback.

On an Apple Silicon laptop with 16 GB unified memory, Gemma 4 E2B through MLX is a reasonable choice if the local runtime produces the stronger result observed there. The model name alone does not determine the result. The runtime and hardware are part of the deployment.

The workflow is the part worth keeping:

```text
inspect the host
  → download one exact quantization
  → start a loopback server
  → wait for a real health signal
  → pin tasks explicitly with hermes-local
  → run fixed capability checks
  → record output, speed, and memory
  → inspect reasoning-channel behavior
  → run a real tool-loop task
  → choose always-on or on-demand
```

That process can be copied to a laptop, VM, ARM board, or larger server. The answer will change with the resources. The measurement method does not have to.
