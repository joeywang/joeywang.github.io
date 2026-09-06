---
layout: post
title: "LLM Strengths and Limitations: A Practical Framework"
description: "A practical framework for deciding when an LLM is the right tool for a task, when it isn't, and how to architect around its limitations."
date: "2026-02-24"
categories: [AI]
tags: [llm, ai, agents]
series: "Software Engineering in the LLM Era"
---
<audio controls preload="metadata" src="/assets/audio/llm-strengths-and-limitations-framework-summary.ogg">
  Your browser does not support the audio element.
</audio>


At some point the theory stops being the bottleneck and you run into the real question:

> **"Should I use an LLM for this task?"**

The industry hype says "AI everything." The skeptics say "LLMs are unreliable." Neither answer is very helpful.

The useful answer is messier: LLMs are great at some tasks and awful at others. The hard part is knowing which bucket your problem falls into before you build the wrong thing.

That is what this article is for. Not abstract debate. A practical way to think about where LLMs help, where they fail, and when they need tools around them.

---

## The Core Insight: LLMs as Reasoning Engines, Not Calculators

The most useful rule I keep coming back to is this:

> **LLMs are excellent for probabilistic reasoning. They are terrible at deterministic computation.**

It explains a surprising amount of LLM behavior.

**Task:** add up a list of numbers.

```
Bad: "What is 237 + 892 + 156 + 445 + 723?"
→ LLM will guess based on number patterns, may get it wrong

Good: "Write Python code to sum [237, 892, 156, 445, 723]"
→ LLM generates deterministic code, code executes correctly
```

The LLM shouldn't compute. It should generate the computation. This pattern, LLM for reasoning and tools for execution, is the foundation of reliable AI systems.

---

## Where LLMs Excel

Based on their architecture (Article 1) and generalization capabilities (Article 2), LLMs are strong in five areas.

**Language understanding and generation.** Summarization, translation, tone adjustment, content generation, question answering from provided context. This is the model's native domain: it was trained on text, so text manipulation is direct pattern matching.

```python
def summarize_support_ticket(ticket_text):
    prompt = f"""
    Summarize this support ticket in 2-3 sentences.
    Identify: issue type, urgency, customer sentiment.
    Ticket: {ticket_text}
    """
    return llm.generate(prompt)
```

**Pattern recognition and classification.** Sentiment analysis, intent classification, entity extraction, anomaly detection in text, categorization. LLMs recognize patterns from training and apply them to novel inputs.

**Cross-domain synthesis.** Combining concepts from different fields, generating analogies, brainstorming, exploring design alternatives, translating business requirements into technical specs. LLMs have seen patterns across many domains and can combine them in novel ways.

**Code generation, with constraints.** Boilerplate, common patterns (CRUD, filters, transformations), refactoring suggestions, documentation, test case generation. Code has regular patterns, and the model has seen millions of examples.

**Explanation and teaching.** Explaining concepts at different levels, generating examples, debugging explanations, documentation. The model has seen countless explanations and can adapt the pattern to your context.

---

## Where LLMs Fail

Now for the part that matters more: knowing when not to use an LLM.

**Precise computation.** Arithmetic beyond simple cases, complex math, cryptographic operations, financial calculations that need precision. LLMs predict number tokens, they don't compute.

```python
# Unreliable
def calculate_compound_interest(principal, rate, years):
    prompt = f"Calculate compound interest for {principal} at {rate}% for {years} years"
    return llm.generate(prompt)  # May be wrong

# Reliable
def calculate_compound_interest(principal, rate, years):
    code = llm.generate(f"Write Python code to calculate compound interest for {principal} at {rate}% for {years} years")
    return exec(code)  # Execute the generated code, not the LLM's answer
```

**Long multi-step reasoning.** Complex logic chains, problems needing working memory, tasks needing backtracking, multi-constraint optimization. LLMs have no working memory: each token is generated independently based on context. The fix is to break the problem into steps and validate each one, rather than asking for the whole answer at once.

**Factual retrieval without RAG.** Recent events, specific facts outside training data, private or proprietary information, precise citations. LLMs generate plausible text, they don't retrieve facts. Ground the answer in retrieved documents instead of trusting the model's memory.

**Deterministic behavior.** Tasks requiring identical outputs, systems needing reproducibility, validation and testing logic, security-critical decisions. LLMs are probabilistic by nature: the same input does not guarantee the same output. Use the LLM to generate rules, then apply those rules deterministically.

**Long-term memory and state.** Remembering across sessions, maintaining conversation state beyond the context window, learning from interactions. LLMs are stateless: each call is independent. Any memory has to be built explicitly, outside the model.

---

## The Decision Framework: Should You Use an LLM?

Ask these questions before committing to an LLM for a task:

1. Is the task probabilistic or deterministic? Deterministic tasks belong in traditional code.
2. Does it require precise computation? If so, have the LLM generate code and execute that, rather than trusting its own arithmetic.
3. Is factual accuracy critical? If so, use RAG or avoid the LLM entirely.
4. How long is the reasoning chain? Short chains (one to three steps) are fine directly; long chains need to be broken up with validation between steps.
5. Does it require memory or state? Build an external memory system. Don't expect the LLM to remember.
6. What's the cost of errors? High-cost errors need validation layers regardless of how good the model seems.
7. Is the output verifiable? If not, think hard about whether an LLM is the right tool at all.

---

## Architectural Patterns: Compensating for Limitations

The patterns worth knowing follow directly from the questions above. LLM output feeding a deterministic validator, when the output format is predictable. LLM proposing code that a sandboxed tool actually executes, when computation is required. Retrieved context feeding the LLM, when facts matter. A chain of LLM calls with validation between steps, when the reasoning is long. Each pattern pairs the LLM's flexibility with a piece of ordinary code that keeps it honest.

---

## LLMs Are Components, Not Solutions

The biggest mistake engineers make is treating LLMs as complete solutions. The wrong mental model is "I'll use an LLM to solve X." The right one is "I'll build a system where the LLM handles the parts it's good at." Like any component, an LLM needs interfaces, validation, integration with other services, and fallbacks. Design systems, not just prompts.

*This is the third article in the **"Software Engineering in the LLM Era"** series. [Read Article 1](/posts/what-is-llm-nature-of-language-models/) | [Read Article 2](/posts/generalization-why-ai-looks-smart/).*
