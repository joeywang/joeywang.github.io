---
layout: post
title: "LLM Strengths and Limitations: A Practical Framework"
date: "2026-02-24"
categories: LLM AI software-engineering series
series: "Software Engineering in the LLM Era"
---

## The Problem

At some point the theory stops being the bottleneck and you run into the real question:

> **"Should I use an LLM for this task?"**

The industry hype says "AI everything." The skeptics say "LLMs are unreliable." Neither answer is very helpful.

The useful answer is messier: **LLMs are great at some tasks and awful at others**. The hard part is knowing which bucket your problem falls into before you build the wrong thing.

That is what this article is for. Not abstract debate. A practical way to think about where LLMs help, where they fail, and when they need tools around them.

---

## The Core Insight: LLMs as Reasoning Engines, Not Calculators

The most useful rule I keep coming back to is this:

> **LLMs are excellent for probabilistic reasoning. They are terrible at deterministic computation.**

It explains a surprising amount of LLM behavior.

### Example: The Same Task, Different Approaches

**Task:** Add up a list of numbers

```
❌ Bad: "What is 237 + 892 + 156 + 445 + 723?"
→ LLM will guess based on number patterns
→ May get it wrong

✅ Good: "Write Python code to sum [237, 892, 156, 445, 723]"
→ LLM generates deterministic code
→ Code executes correctly
```

The LLM shouldn't *compute*. It should *generate the computation*.

This pattern—**LLM for reasoning, tools for execution**—is the foundation of reliable AI systems.

---

## The Strength Matrix: Where LLMs Excel

Based on their architecture (Article 1) and generalization capabilities (Article 2), LLMs are strong in these areas:

### 1. Language Understanding and Generation

**Strengths:**
- Summarization
- Translation
- Tone adjustment
- Content generation
- Question answering (from provided context)

**Why it works:** This is the model's native domain. It was trained on text, so text manipulation is direct pattern matching.

**Example:**
```python
# Reliable use case
def summarize_support_ticket(ticket_text):
    prompt = f"""
    Summarize this support ticket in 2-3 sentences.
    Identify: issue type, urgency, customer sentiment.
    
    Ticket: {ticket_text}
    """
    return llm.generate(prompt)
```

---

### 2. Pattern Recognition and Classification

**Strengths:**
- Sentiment analysis
- Intent classification
- Entity extraction
- Anomaly detection (in text)
- Categorization

**Why it works:** LLMs recognize patterns from training and can apply them to novel inputs.

**Example:**
```python
# Reliable use case
def classify_feature_request(request_text):
    prompt = f"""
    Classify this feature request:
    - Category: UI, Backend, API, Performance, Security
    - Priority: High, Medium, Low
    - Effort: Small, Medium, Large
    
    Request: {request_text}
    
    Output as JSON.
    """
    return llm.generate(prompt)
```

---

### 3. Cross-Domain Synthesis

**Strengths:**
- Combining concepts from different fields
- Generating analogies
- Brainstorming solutions
- Exploring design alternatives
- Translating between domains (e.g., business requirements → technical specs)

**Why it works:** LLMs have seen patterns across many domains and can combine them in novel ways.

**Example:**
```python
# Reliable use case
def generate_architecture_options(requirements):
    prompt = f"""
    Given these requirements, propose 3 architecture options.
    For each, list:
    - Components
    - Trade-offs
    - When to choose this approach
    
    Requirements: {requirements}
    """
    return llm.generate(prompt)
# Output: Ideas for human evaluation
```

---

### 4. Code Generation (with Constraints)

**Strengths:**
- Boilerplate generation
- Common patterns (CRUD, filters, transformations)
- Refactoring suggestions
- Documentation
- Test case generation

**Why it works:** Code has regular patterns. The model has seen millions of examples.

**Example:**
```python
# Reliable use case
def generate_crud_endpoints(model_name, fields):
    prompt = f"""
    Generate REST API endpoints for {model_name} with fields: {fields}
    Include: GET list, GET single, POST, PUT, DELETE
    Use Python FastAPI.
    """
    return llm.generate(prompt)
# Output: Review and test before deploying
```

---

### 5. Explanation and Teaching

**Strengths:**
- Explaining concepts at different levels
- Generating examples
- Creating learning materials
- Debugging explanations
- Documentation generation

**Why it works:** The model has seen countless explanations and can adapt patterns to your context.

**Example:**
```python
# Reliable use case
def explain_error(error_message, code_context):
    prompt = f"""
    Explain this error in simple terms:
    Error: {error_message}
    Code: {code_context}
    
    Include:
    1. What caused this
    2. How to fix it
    3. How to prevent it
    """
    return llm.generate(prompt)
```

---

## The Limitation Matrix: Where LLMs Fail

Now for the critical part—knowing when NOT to use LLMs.

### 1. Precise Computation

**Weaknesses:**
- Arithmetic beyond simple cases
- Complex mathematical reasoning
- Cryptographic operations
- Financial calculations requiring precision

**Why it fails:** LLMs predict number tokens, they don't compute.

**Example:**
```python
# ❌ Unreliable
def calculate_compound_interest(principal, rate, years):
    prompt = f"Calculate compound interest for {principal} at {rate}% for {years} years"
    return llm.generate(prompt)  # May be wrong

# ✅ Reliable
def calculate_compound_interest(principal, rate, years):
    code = llm.generate(f"Write Python code to calculate compound interest for {principal} at {rate}% for {years} years")
    # Execute the generated code, not the LLM's answer
    return exec(code)
```

---

### 2. Long Multi-Step Reasoning

**Weaknesses:**
- Complex logic chains
- Problems requiring working memory
- Tasks needing backtracking
- Multi-constraint optimization

**Why it fails:** LLMs have no working memory. Each token is generated independently based on context.

**Example:**
```python
# ❌ Unreliable for complex cases
def solve_logic_puzzle(puzzle_description):
    return llm.generate(f"Solve: {puzzle_description}")
# Works for simple puzzles, fails as complexity increases

# ✅ Better approach
def solve_logic_puzzle(puzzle_description):
    # Break into steps, validate each
    step1 = llm.generate(f"Identify constraints: {puzzle_description}")
    validated1 = verify_constraints(step1)
    step2 = llm.generate(f"Given {validated1}, what's the next deduction?")
    # ... chain with validation
    return combine_results(validated1, step2, ...)
```

---

### 3. Factual Retrieval (Without RAG)

**Weaknesses:**
- Recent events (post-training)
- Specific facts not in training
- Private or proprietary information
- Precise citations and references

**Why it fails:** LLMs generate plausible text, they don't retrieve facts.

**Example:**
```python
# ❌ Unreliable
def get_company_revenue(company_name):
    return llm.generate(f"What is {company_name}'s revenue in 2025?")
# May hallucinate

# ✅ Reliable (RAG pattern)
def get_company_revenue(company_name):
    documents = search_knowledge_base(company_name)
    return llm.generate(f"Based on these documents: {documents}, what is {company_name}'s revenue?")
# Grounded in retrieved context
```

---

### 4. Deterministic Behavior

**Weaknesses:**
- Tasks requiring identical outputs
- Systems needing reproducibility
- Validation and testing logic
- Security-critical decisions

**Why it fails:** LLMs are probabilistic by nature. Same input ≠ same output.

**Example:**
```python
# ❌ Unreliable
def validate_user_input(user_input):
    result = llm.generate(f"Is this input valid? {user_input}")
    return result == "valid"  # May vary between calls

# ✅ Reliable
def validate_user_input(user_input):
    # Use LLM to generate validation rules, apply deterministically
    rules = llm.generate(f"Generate validation rules for: {user_input}")
    return apply_rules_deterministically(rules, user_input)
```

---

### 5. Long-Term Memory and State

**Weaknesses:**
- Remembering across sessions
- Maintaining conversation state (beyond context window)
- Learning from user interactions
- Accumulating knowledge over time

**Why it fails:** LLMs are stateless. Each call is independent.

**Example:**
```python
# ❌ Won't work
def chat_with_user(user_id, message):
    # LLM won't remember previous conversations
    return llm.generate(f"User says: {message}")

# ✅ Works (explicit memory)
def chat_with_user(user_id, message):
    history = get_conversation_history(user_id)
    response = llm.generate(f"History: {history}. User says: {message}")
    save_conversation_history(user_id, message, response)
    return response
```

---

## The Decision Framework: Should You Use an LLM?

Use this checklist when evaluating a use case:

### Questions to Ask

```
1. Is the task probabilistic or deterministic?
   → Probabilistic: LLM suitable
   → Deterministic: Use traditional code

2. Does it require precise computation?
   → Yes: LLM generates code, code executes
   → No: LLM can handle directly

3. Is factual accuracy critical?
   → Yes: Use RAG or avoid LLM
   → No: Direct LLM generation OK

4. How long is the reasoning chain?
   → Short (1-3 steps): LLM suitable
   → Long: Break into steps with validation

5. Does it require memory/state?
   → Yes: Build external memory system
   → No: Stateless LLM works

6. What's the cost of errors?
   → High: Add validation layers
   → Low: Direct LLM use acceptable

7. Is the output verifiable?
   → Yes: LLM + validation pattern
   → No: Consider if LLM is appropriate
```

### Decision Tree

```
                    ┌─────────────────┐
                    │    New Task     │
                    └────────┬────────┘
                             ↓
                    ┌─────────────────┐
                    │ Deterministic?  │
                    └────────┬────────┘
                         Yes │ No
                             ↓
                    ┌─────────────────┐
                    │ Don't use LLM   │
                    │ Use code        │
                    └─────────────────┘
                             
                         No
                             ↓
                    ┌─────────────────┐
                    │ Needs facts?    │
                    └────────┬────────┘
                         Yes │ No
                             ↓
                    ┌─────────────────┐
                    │ Use RAG         │
                    │ + LLM           │
                    └─────────────────┘
                             
                         No
                             ↓
                    ┌─────────────────┐
                    │ Precise math?   │
                    └────────┬────────┘
                         Yes │ No
                             ↓
                    ┌─────────────────┐
                    │ LLM generates   │
                    │ code to execute │
                    └─────────────────┘
                             
                         No
                             ↓
                    ┌─────────────────┐
                    │ Direct LLM use  │
                    │ (with validation│
                    │ if high stakes) │
                    └─────────────────┘
```

---

## Architectural Patterns: Compensating for Limitations

### Pattern 1: LLM + Validator

```python
def process_with_validation(input_data):
    # LLM generates
    result = llm.generate(f"Process: {input_data}")
    
    # Traditional code validates
    if is_valid(result):
        return result
    else:
        return handle_error(input_data)
```

**Use when:** Output format is predictable and verifiable.

---

### Pattern 2: LLM + Tool

```python
def calculate_with_tool(question):
    # LLM figures out what to compute
    computation = llm.generate(f"What code computes: {question}?")
    
    # Tool executes
    result = execute_code(computation)
    
    return result
```

**Use when:** Computation is required.

---

### Pattern 3: LLM + Memory (RAG)

```python
def answer_with_context(question):
    # Retrieve relevant facts
    context = retrieve_from_knowledge_base(question)
    
    # LLM answers based on context
    answer = llm.generate(f"Context: {context}. Question: {question}")
    
    return answer
```

**Use when:** Factual accuracy matters.

---

### Pattern 4: LLM Chain with Validation

```python
def solve_complex_task(task):
    # Break into steps
    step1 = llm.generate(f"Step 1 for: {task}")
    validated1 = validate_step1(step1)
    
    step2 = llm.generate(f"Step 2 given: {validated1}")
    validated2 = validate_step2(step2)
    
    # Combine
    return combine(validated1, validated2)
```

**Use when:** Reasoning chain is long.

---

## The Meta-Lesson: LLMs Are Components, Not Solutions

The biggest mistake engineers make is treating LLMs as complete solutions:

```
❌ Wrong mental model: "I'll use an LLM to solve X"
✅ Right mental model: "I'll build a system where LLM handles the parts it's good at"
```

LLMs are powerful components. But like any component, they need:

- **Interfaces** (prompts, APIs)
- **Validation** (testing, monitoring)
- **Integration** (tools, memory, other services)
- **Fallbacks** (error handling, alternatives)

---

## Key Takeaways

- **LLMs excel at**: language tasks, pattern recognition, cross-domain synthesis, code generation, explanation.
- **LLMs fail at**: precise computation, long reasoning chains, factual retrieval (without RAG), deterministic behavior, stateful operations.
- **Use the decision framework**: Ask the 7 questions before using an LLM.
- **Apply architectural patterns**: LLM + Validator, LLM + Tool, LLM + Memory, LLM Chain.
- **LLMs are components, not solutions**: Design systems, not just prompts.

---

## Next Article

In **Article 4: AI Application Architecture—LLM + Memory + Tools**, we'll dive deep into building complete systems. We'll explore how to combine LLMs with memory systems, external tools, and knowledge bases to create reliable, production-ready AI applications.

---

*This is the third article in the **"Software Engineering in the LLM Era"** series. [Read Article 1](/posts/what-is-llm-nature-of-language-models/) | [Read Article 2](/posts/generalization-why-ai-looks-smart/).*

---

💬 **What's your experience with LLM strengths and failures? Share a use case that surprised you in the comments!** 🚀
