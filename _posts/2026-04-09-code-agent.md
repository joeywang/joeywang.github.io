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

## Five Things That Actually Matter

### Separate the thinking channel from tool calls

Gemma 4 can output reasoning tokens and tool calls in the same response. If your client doesn't handle both channels separately, they get mixed together and the model gets confused about which format to use. In practice, I found that enabling the thinking channel for simple tasks made the model more likely to *talk about* tool calls rather than make them. I now only enable reasoning for planning phases and debugging sessions.

### Message history has to be exact

Each tool result needs to be appended as a proper `tool` role message with the right `tool_call_id`. If you get this wrong — say, you append it as an `assistant` message or forget the ID — Gemma 4 will notice. Smaller models might not care, but Gemma 4 expects the format to be correct. When it isn't, the model either ignores the result or breaks out of the tool loop entirely.

### Streaming is not optional

Don't execute on partial JSON. Don't execute on the first chunk that looks like a tool call. Buffer the full response, then parse it. I learned this the hard way when a tool call's JSON arguments got split across chunks and my parser choked on `{"city": "Bright` instead of `{"city": "Brighton"}`.

### The model doesn't execute anything

This sounds obvious until you realize your agent is waiting for the model to "decide" whether a tool succeeded. The model decides *what* to call. Your code executes it. Your code appends the result. Your code calls the model again. The model has no awareness of whether the tool actually worked — it only sees the text you give it.

### Gemma 4 is not OpenAI

If you're passing messages through an OpenAI compatibility layer, you're probably losing information. Gemma 4 prefers user/model turns with flattened system instructions. The OpenAI format with separate `system`, `developer`, and `tool` roles needs an adapter to translate into something Gemma understands well. I found that simplifying the message format — fewer role types, clearer turn structure — made tool calling more reliable.

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
