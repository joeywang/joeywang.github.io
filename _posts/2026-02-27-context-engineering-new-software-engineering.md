---
layout: post
title: "Context Engineering: The New Software Engineering"
description: "Why reliable AI behavior comes from designing the whole context, not tuning a single clever prompt, and the five layers that make up good context."
date: "2026-02-27"
categories: [AI]
series: "Software Engineering in the LLM Era"
tags: [llm, ai, agents]
---
<audio controls preload="metadata" src="/assets/audio/context-engineering-new-software-engineering-summary.ogg">
  Your browser does not support the audio element.
</audio>

You build an AI application. The model is good. The architecture is fine. And still the outputs wobble all over the place.

Sometimes the answer is sharp and exactly on target. Sometimes it is weirdly cautious. Sometimes it sounds confident and misses the point entirely.

So you do what everybody does at first. You tweak the prompt. Then you tweak it again. You add examples. You tighten the system message. You make it more specific, then less specific. Now it is better on one case and worse on three others.

That phase has a name: prompt engineering. Useful name. Too small for the actual job.

What the better teams seem to have figured out is this: prompt engineering is tactical, context engineering is strategic. If you want reliable behavior, you are not really writing prompts anymore. You are designing context. That is what this article is about.

---

## From Prompt Engineering to Context Engineering

**Prompt engineering (2022-2023):** crafting the perfect single prompt, wording and examples and formatting, with the mindset of "what should I ask?"

**Context engineering (2024+):** designing the entire information environment, with the mindset of "what context does the AI need?" The skill is architecture and information design, not just wording.

```
Phase 1: Prompt Engineering
"Write a function to sort users by name"
→ Single prompt, hope for the best

Phase 2: Prompt + Examples
System: You are a coding assistant
User: Sort users
Examples: [input → output pairs]

Phase 3: Context Engineering
System Role: Senior Python developer
Project Context: Django app, specific style
Conversation History: Previous decisions
Knowledge Base: Project docs, APIs
Tools Available: Linter, tests, formatter
User Preferences: Concise, production-ready
Current Task: Sort users by name
```

Context is the new code. That line can sound a little dramatic, but I think it is directionally right. In traditional programming, you write logic. In AI programming, a lot of the real work shifts toward designing the information environment that shapes behavior.

---

## The Context Stack: Layers of Information

Think of context as a stack of layers, each serving a different purpose:

```
Layer 5: Task Context        - the specific request, right now
Layer 4: Conversation Context - session history, prior decisions
Layer 3: Knowledge Context    - retrieved documents, domain facts (RAG)
Layer 2: Instruction Context  - behavioral rules, output format
Layer 1: Identity Context     - who the AI is in this interaction
```

Let's examine each layer.

---

## Layer 1: Identity Context

Identity context defines who the AI is in this interaction: its role, expertise, relationship to the user, and personality. Be specific about role and expertise, define the relationship dynamic, and set personality expectations. Don't be vague ("You are a helpful assistant"), don't over-constrain, and don't contradict yourself ("be creative but follow rules strictly").

```python
identity_context = {
    "role": "Senior software architect",
    "expertise": ["system design", "Python", "distributed systems"],
    "relationship": "Collaborative advisor, not order-taker",
    "personality": "Direct, practical, questions assumptions",
    "constraints": "Does not write code without understanding requirements",
}
```

---

## Layer 2: Instruction Context

Instruction context defines how the AI should behave and what rules to follow: behavioral guidelines, output requirements, and constraints.

```python
instruction_context = """
BEHAVIORAL GUIDELINES:
- Ask clarifying questions when requirements are ambiguous
- Explain reasoning before giving answers

OUTPUT REQUIREMENTS:
- Code must include type hints and docstrings
- Include tests for new functionality

CONSTRAINTS:
- Do not use external libraries without permission
- Flag potential security issues
"""
```

---

## Layer 3: Knowledge Context (RAG)

Knowledge context provides the domain-specific information the AI needs to answer accurately: project docs, codebase conventions, business rules, and whatever gets retrieved for the current query. The implementation is the RAG pattern from the last article: embed the query, retrieve the top matches, rank them, and keep only what fits the token budget.

```python
def build_knowledge_context(query, project_id, max_tokens=2000):
    results = vector_db.similarity_search(embed(query), filter={"project_id": project_id}, top_k=10)
    ranked = rerank(results, query)
    selected = select_within_token_limit(ranked, max_tokens)
    return "\n".join(f"[Source: {r.metadata['source']}]\n{r.text}" for r in selected)
```

---

## Layer 4: Conversation Context

Conversation context provides continuity: history, decisions made mid-conversation, user preferences discovered along the way, and current task state.

```python
def build_conversation_context(messages, decisions, preferences, max_tokens=4000):
    parts = []
    if decisions:
        parts.append("DECISIONS MADE:\n" + "\n".join(f"- {d}" for d in decisions))
    if preferences:
        parts.append("USER PREFERENCES:\n" + "\n".join(f"- {k}: {v}" for k, v in preferences.items()))
    parts.append("CONVERSATION:\n" + within_token_budget(messages, max_tokens))
    return "\n\n".join(parts)
```

---

## Layer 5: Task Context

Task context is the immediate request: what the user wants right now, the parameters, task-specific constraints, and what "done" looks like.

```python
task = (TaskContextBuilder()
    .set_request("Refactor the user authentication module")
    .add_parameter("current_file", "auth.py")
    .add_constraint("Maintain backward compatibility")
    .add_success_criterion("Reduced cyclomatic complexity")
    .build())
```

---

## Putting the Layers Together

In practice, a context orchestrator assembles these five layers in order, checks the running token count against a budget, and raises an error rather than silently truncating something important. The layers are additive: identity and instructions are usually static per scenario, knowledge and conversation vary per request, and task context always goes last, closest to the actual question. The discipline is in tracking the token budget explicitly rather than hoping everything fits.

---

## Context Engineering Patterns

**Progressive disclosure.** Start with just the request, and add history or clarifying notes only as the conversation warrants it. Use this when the token budget is tight or you want to minimize context noise.

```python
def build_progressive_context(initial_request, conversation):
    context = f"Task: {initial_request}"
    if len(conversation) > 1:
        context += f"\n\nConversation History:\n{format_history(conversation)}"
    if detect_ambiguity(initial_request):
        context += "\n\nNote: If requirements are unclear, ask clarifying questions."
    return context
```

**Context templates.** For recurring scenarios (code review, debugging), define the role, focus, and output format once and fill in variables per request, rather than reconstructing the same context from scratch each time.

**Context chaining.** For conversations that span sessions, summarize the prior exchange rather than replaying it verbatim, and carry the summary forward as the new context's starting point.

---

## Context Quality Metrics

How do you know if your context engineering is working? Four things worth measuring: completeness (does the output indicate missing information, like "I don't have enough information"), relevance (does the output actually use the terms and facts you fed it), efficiency (how many tokens does the context cost per unit of quality), and satisfaction (does the user rate the result well). None of these need to be exotic. A simple heuristic check for each is enough to catch regressions before they become a pattern.

---

Context is the new code. Prompt engineering optimizes a single message. Context engineering treats the entire information environment, identity, instructions, knowledge, conversation, and task, as the thing you design, version, and debug.
