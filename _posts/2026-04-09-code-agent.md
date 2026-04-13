---
layout: post
title: "Building a Local Coding Agent (Codex/Claude-Code Style) with Gemma"
date: 2026-04-09
categories: AI LLM Gemma Ollama coding-agent
---

# Building a Local Coding Agent (Codex/Claude-Code Style) with Gemma

Last week I spent an evening trying to get Gemma 4 (26B) to run a simple coding task through my own agent: "find all the Ruby files in this directory and replace `before_filter` with `before_action`." The first tool call worked perfectly — the model correctly asked to run `find . -name '*.rb'`. But when I fed the file list back to it, instead of calling `sed` or a file editor, it started *explaining* what I should do next, as if I were asking it for advice rather than expecting it to act.

I bumped the temperature down. I rewrote the prompt three times. I tried adding explicit instructions like "you must call a tool." Nothing helped.

The problem wasn't Gemma 4. The problem was my agent. I was treating it like a chatbot with tool access, but what I actually needed was a state machine.

## What's Missing from Most Local Agent Setups

Ollama gives you model execution, streaming, and a tool call output format. It even supports a thinking channel now. But it doesn't give you an agent loop. It doesn't execute tools, manage state, or decide whether to call the model again. It just returns whatever the model outputs and leaves the rest to you.

`llama.cpp` is even more bare — you get raw model inference and nothing else. That's fine if you want to build everything from scratch. But it means you can't just drop in a tool schema and expect multi-step behavior to work.

This gap is where things fall apart. The model knows how to request a tool call. But if your runtime doesn't execute that call, append the result to the message history, and feed it back into the model, the conversation stops dead. Or worse, the model improvises — which usually means it starts describing what *would* happen if someone ran the tool, instead of actually asking for it to run.

## The Agent Loop Is the Whole Thing

Here's the core loop, stripped down:

```python
messages = initial_messages

while True:
    response = llm(messages, tools=tools)

    if response.tool_calls:
        messages.append(response)
        for call in response.tool_calls:
            result = execute_tool(call)
            messages.append({
                "role": "tool",
                "tool_call_id": call.id,
                "content": json.dumps(result)
            })
        # loop back
    else:
        return response.content
```

That's it. The `continue` back into the model after each tool execution is the part most people miss (or forget to implement correctly). Without it, you get one tool call and then nothing.

### What I Got Wrong First

My original code collected the streaming response and checked for tool calls, but I was only looking at the *first* response chunk. With Gemma 4's thinking channel enabled, the first chunk contained reasoning text, and the actual tool call came several chunks later. I was executing on incomplete output.

The fix was simple: accumulate the full stream, then parse. Don't act on partial data.

## What the Model Exposes vs What the Agent Must Build

When you use something like Claude Code or Codex, the smooth experience comes from a tight integration between what the model exposes and what the agent runtime does with it. Here's a mapping of the main LLM features to what your agent needs to support.

### Tool / Function Calling

**What the model does:** Outputs structured tool call objects with a name and arguments. It doesn't call the tool — it just signals intent. In the raw token stream, this often looks like a special marker followed by JSON:

```
</think>

{"name": "run_shell", "arguments": {"command": "ls -la"}}
```

**What the agent must build:** Parse the tool call from the stream, validate the JSON arguments, dispatch to the right function, capture stdout/stderr/exit code, and return the result as a structured `tool` role message. The model expects the result to come back with the same `tool_call_id` it used. If you lose that ID, the model has no way to know which tool call this result corresponds to — especially important when the model fires multiple tool calls in parallel.

### Thinking / Reasoning Channel

**What the model does:** Emits reasoning tokens before the actual answer or tool call. These tokens represent the model's "chain of thought" — the step-by-step reasoning that leads to a decision. In some models, these tokens are hidden from the final output but still influence the model's behavior.

**What the agent must build:** Separate the thinking tokens from the actual output. You have two choices: show them to the user (for transparency, like Claude Code does) or hide them (for a cleaner UI). Critically, thinking tokens must *not* be treated as tool calls or as the final answer. They're an internal monologue. If your agent confuses them with real output, the user sees garbled text and the tool loop breaks.

I found that enabling the thinking channel for simple tasks actually made things worse. The model would reason out loud about what tool to call, then somehow convince itself the task was already done. Now I only enable reasoning for the planning phase — figuring out what steps to take — and disable it for the actual tool execution loop.

### Streaming

**What the model does:** Emits tokens one at a time (or in small batches). Tool call JSON often arrives across multiple chunks. Thinking tokens and answer tokens can interleave.

**What the agent must build:** A streaming buffer that accumulates all chunks until the model signals completion. Only then should you parse the full response to decide what happened. If you act on partial data, you'll try to execute a tool call with truncated JSON, or display an incomplete answer to the user.

This is the most common bug I see in custom agents. The stream arrives in chunks, the first chunk looks like a tool call, the agent fires off the tool, and the rest of the tool call data arrives too late. The model then gets confused because it never got a result for the *full* tool call it made.

### Message Roles and Format

**What the model does:** Expects messages in a specific format. Different models have different expectations. OpenAI models expect `system`, `user`, `assistant`, and `tool` roles. Gemma 4 works better with fewer role types — mainly `user` and `model` — with system instructions flattened into the conversation context.

**What the agent must build:** A message format adapter that translates between your internal representation and what the model expects. If you're using Ollama's OpenAI-compatible endpoint, the adapter is built in. If you're talking to the model directly (llama.cpp, or Ollama's native API), you need to handle this yourself.

The thing that tripped me up: I was appending tool results with a `tool` role, but my Ollama setup expected them as part of a `user` turn. The model received messages in a format it didn't recognize, and the tool loop silently broke — no error, just the model ignoring the result and generating something else.

### Context Window Management

**What the model does:** Has a fixed context window (e.g., 8K, 16K tokens). Everything in the message history — user prompts, model responses, tool results — consumes tokens. When you exceed the window, older tokens get truncated.

**What the agent must build:** A strategy for managing context growth. Tool results can be large — a `grep -r` across a codebase might return thousands of lines. If you dump every tool result into the message history without thinking, you'll burn through your context window in three turns.

Common approaches: summarize tool results before appending, truncate output that exceeds a threshold, or maintain a separate "memory" that the model can query instead of keeping everything in the active context. For coding tasks, I've had good luck truncating file contents to relevant sections and summarizing long shell output.

### Parallel Tool Calls

**What the model does:** Can emit multiple tool calls in a single response when it determines they're independent — for example, reading five files at once. The model expects these to be executed and the results returned in the same turn.

**What the agent must build:** Logic to detect multiple tool calls, decide whether to run them in parallel or sequentially, and collect all results before feeding them back to the model. Running independent file reads in parallel is a nice optimization, but running dependent tool calls in parallel (read a file, then write to it) is a bug.

### Stop Sequences and Completion Detection

**What the model does:** Signals that it's done generating by hitting a stop sequence or a special end-of-turn token. The runtime (Ollama, llama.cpp) tells you when generation is complete.

**What the agent must build:** Use the completion signal to decide the next step. If the response contains tool calls → execute and loop. If it's plain text → return it to the user. Without reliable completion detection, you can't reliably distinguish between "the model is still thinking" and "the model is done."

## Putting It All Together

Here's how these pieces interact in a working agent:

```
User sends request
    ↓
Agent builds message history (with context management)
    ↓
Agent calls LLM with tools schema
    ↓
LLM streams tokens (thinking + answer + possibly tool calls)
    ↓
Agent buffers the full stream
    ↓
Agent parses: thinking tokens → tool calls OR final answer
    ↓
If tool calls:
    → Agent executes them (parallel if independent)
    → Agent captures results
    → Agent appends results to message history
    → Agent loops back to LLM call
If final answer:
    → Agent returns to user
```

Every arrow in that diagram is a place where something can go wrong. The streaming buffer is where partial-data bugs live. The message history is where format mismatches cause silent failures. The tool executor is where you need to handle errors, timeouts, and large outputs.

## A Minimal Working Setup

The message type:

```typescript
type Message =
  | { role: "user"; content: string }
  | { role: "assistant"; content?: string; tool_calls?: ToolCall[] }
  | { role: "tool"; tool_call_id: string; content: string }
```

A tool schema — nothing fancy:

```json
{
  "name": "get_weather",
  "description": "Get weather by city",
  "parameters": {
    "type": "object",
    "properties": {
      "city": { "type": "string" }
    },
    "required": ["city"]
  }
}
```

The core loop:

```typescript
async function runAgent(messages: Message[]): Promise<string> {
  while (true) {
    const response = await llm(messages)

    if (response.tool_calls) {
      messages.push(response)

      for (const call of response.tool_calls) {
        const result = await executeTool(call)

        messages.push({
          role: "tool",
          tool_call_id: call.id,
          content: JSON.stringify(result)
        })
      }

      continue
    }

    return response.content
  }
}
```

## Planner and Executor Split

One thing I picked up from watching how Claude Code behaves: it doesn't use a single model call for everything. There's a planning phase (which may involve tool calls) and an execution phase (which produces the final answer). You can approximate this by using one pass of the model to decide on steps and call tools, then a second pass — sometimes even with temperature set to 0 — to synthesize the result.

It's not strictly necessary for simple tasks, but once you're doing multi-step refactoring work, the split makes the agent more predictable. The planner can wander through tool calls without worrying about producing a clean final answer. The executor gets a complete set of tool results and just needs to summarize.

## Ollama vs llama.cpp

Just use Ollama to start. You'll save days. The tool support works out of the box, the thinking channel is already wired in, and you can focus on building your agent loop instead of wrestling with low-level inference.

Switch to `llama.cpp` only when you need control over something that Ollama hides from you. I haven't needed to yet, but when I do, it'll be because I want to optimize the prompt format or handle the thinking channel more precisely.

## What to Skip

You don't need a complex session system. You don't need the full Ollama API. You don't need abstractions around abstractions. You need:

- A working tool loop
- A streaming buffer
- A prompt adapter for Gemma
- A state machine with maybe four states
- A tool executor that actually executes things

## My Setup on M1 Pro 32GB

- **Model:** `gemma4:26b`
- **Runtime:** Ollama
- **Context:** 8K (16K if the task needs it, but it burns memory fast)
- **Temperature:** 0.1 for tool-heavy tasks, 0.3 for planning

26B fits in unified memory alongside everything else I'm running, and the tool calling is reliable enough that I actually use it for real tasks now — not just experiments.

The thing I keep coming back to is that the model quality barely matters once your loop is correct. A good agent loop makes a mediocre model feel capable. A broken agent loop makes a great model feel useless.
