---
layout: post
title: "Building a Local Coding Agent (Codex/Claude-Code Style) with Gemma"
date: 2026-04-09
categories: AI LLM Gemma Ollama coding-agent
---

# Building a Local Coding Agent (Codex/Claude-Code Style) with Gemma

If you've tried running **Gemma 4 (especially the 26B variant)** locally with coding tools — Pi, OpenCode, or your own agent — you've probably noticed some frustrating behavior. Tool calls sometimes work and then stall. The model describes tool usage instead of actually calling it. Reasoning mode improves the first step but breaks on the second. OpenAI-style prompts behave inconsistently.

This is not because Gemma 4 is bad. It's because **modern LLMs don't just need prompts — they need a runtime**. Models like Gemma 4 assume structured tool calling, multi-turn control loops, a separation of thinking versus acting, and correct message formatting. If your agent runtime doesn't support these properly, things break in exactly the ways described above.

## The Key Idea

To build something like Codex, Claude Code, Pi, or OpenCode, you need to implement the missing layer between the model and reality: **a deterministic agent runtime built as a state machine**. This is the core architecture that turns a language model from a chatbot into a working coding agent.

## What Ollama Gives You (and What It Doesn't)

Ollama provides model execution, streaming, tool call output formatting, and optionally a thinking channel. What it does not give you is a full agent loop, tool execution, state management, or correct continuation logic. The same applies to `llama.cpp` — perhaps even more so, since it offers even fewer abstractions.

This gap is where most agent implementations fail. The model is only one piece; the runtime that orchestrates it is equally important.

## The Architecture You Actually Need

At its core, a minimal agent system follows this flow:

```
User → Planner (LLM) → Tool decision?
  → YES → Tool Executor → Tool Result → back to LLM
  → NO  → Final Answer
```

Most broken agents do this:

```
LLM → tool call → execute → DONE ❌
```

The correct loop looks like this:

```python
while True:
    response = llm(messages)

    if response contains tool_call:
        execute tool
        append tool result to messages
        continue
    else:
        return final answer
```

Gemma 4 makes missing control flow more obvious because it introduces a thinking/reasoning channel, a stricter function calling format, and an expectation of multi-step loops. Smaller, less capable models tend to "fake it" through pattern matching. Gemma 4 exposes the bug in your runtime.

## Critical Design Principles

### 1. Separate Thinking from Acting

Gemma 4 internally separates reasoning (hidden thinking), tool calls (structured actions), and the final answer (user-facing output). Your runtime must respect this boundary. Never mix thinking and execution logic. The thinking channel is for planning and reflection; the tool channel is for deterministic action.

### 2. The Agent Must Be a State Machine

You are not building a chatbot. You are building a state machine with well-defined transitions:

```
WAITING_FOR_MODEL → EXECUTING_TOOL → WAITING_FOR_NEXT_STEP → DONE
```

Without explicit state management, multi-step tasks will break at unpredictable points. Each state should have clear entry conditions, exit conditions, and error handling.

### 3. Streaming Must Be Accumulated

This is where many systems fail. Gemma and Ollama output partial tool calls, partial JSON, and partial reasoning tokens. If you execute on incomplete output, the agent breaks. You must collect the full stream before deciding what happened, then act on the complete result.

### 4. Tool Execution Is Not the Model's Job

The model's only responsibility is to decide which tool to call and with what arguments. Your system must execute the tool, return the result as a structured message, and call the model again. This separation keeps the model focused on reasoning while the runtime handles deterministic execution.

### 5. Prompt Format Must Match the Model

Gemma 4 is not OpenAI-native. It prefers user/model turns with flattened system instructions. If your agent relies on OpenAI-style system, developer, and tool roles, you need a prompt adapter to translate between formats. Mismatched prompt formats are a common source of inconsistent tool calling behavior.

## Building a Codex/Claude-Style Agent

Now let's build something concrete.

**Step 1: Define your message format.** Start with a clean internal representation:

```typescript
type Message =
  | { role: "user"; content: string }
  | { role: "assistant"; content?: string; tool_calls?: ToolCall[] }
  | { role: "tool"; name: string; content: string }
```

**Step 2: Define your tool schema.** Keep it simple and explicit:

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

**Step 3: Implement the core loop.** Here is a complete implementation:

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
          name: call.name,
          content: JSON.stringify(result)
        })
      }

      continue
    }

    return response.content
  }
}
```

**Step 4: Add reasoning carefully.** Enable the thinking channel only for planning, complex coding tasks, and debugging. Disable it for tool follow-ups and simple Q&A. The reasoning tokens add latency and can interfere with the tool calling format if the model isn't in a reasoning-appropriate context.

**Step 5: Consider a planner/executor split.** Instead of having one model do everything, use a planner that decides steps and may call tools, and an executor that synthesizes the final answer. This mirrors how Claude Code and Codex actually work internally, and it produces more reliable results with complex multi-step tasks.

## Ollama vs llama.cpp

Ollama offers easier setup, built-in tool support, and a thinking channel out of the box. The tradeoff is less control over behavior, hidden implementation details, and sometimes inconsistent parsing. It's the right choice for getting started quickly.

`llama.cpp` gives you full control, predictable behavior, and is better suited for custom agents where you need to own every part of the loop. The tradeoff is that you must build everything yourself — there is no magic layer. It's the right choice once you understand the architecture and need to optimize it.

You don't need to rebuild all of Ollama's features. Focus on the essentials: the tool loop, a streaming accumulator, a Gemma-specific prompt adapter, the state machine, and the tool executor. Skip the full Ollama API, complex session systems, and unnecessary abstractions.

## Common Failure Modes

When your first tool call works but the next step fails, the cause is usually a tool result that wasn't appended correctly to the message history, or a stream that wasn't fully collected before execution.

When the model explains what it would do instead of actually calling the tool, the cause is usually prompt ambiguity, temperature that is too high, or a weak tool schema that doesn't make the calling format explicit.

When reasoning mode breaks the tool loop, the cause is usually a client that doesn't handle the thinking channel properly or mixed message roles that confuse the model about which channel to use.

When the agent works in one framework but not another, the cause is typically different prompt formats or different tool-call parsing conventions between the runtimes.

## Recommended Setup for M1 Pro (32GB)

For an M1 Pro with 32GB of unified memory, the recommended configuration is Gemma 4 at 26B, starting with Ollama and moving to `llama.cpp` for advanced use. Set the context window to 8K–16K and keep the temperature between 0.1 and 0.3 for deterministic tool calling behavior.

The architecture follows a simple pattern: Gemma 4 acts as the planner, your agent runtime orchestrates the loop, tools handle web access, file operations, and shell commands, and the result loops back into Gemma for the next step.

## Final Takeaway

Good agents are not prompt engineering problems. They are control system problems. Gemma 4 is powerful, but only when your loop is correct, your state is consistent, and your tool flow is deterministic. Start with the minimal state machine, get the tool loop right, and everything else follows from there.
