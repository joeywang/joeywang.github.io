---
layout: post
title: "Context Engineering: The New Software Engineering"
date: "2026-02-27"
categories: LLM AI software-engineering series
series: "Software Engineering in the LLM Era"
---

## The Problem

You build an AI application. The model is good. The architecture is fine. And still the outputs wobble all over the place.

Sometimes the answer is sharp and exactly on target. Sometimes it is weirdly cautious. Sometimes it sounds confident and misses the point entirely.

So you do what everybody does at first. You tweak the prompt. Then you tweak it again. You add examples. You tighten the system message. You make it more specific. Then less specific. Now it is better on one case and worse on three others.

That phase has a name: **prompt engineering**.

Useful name. Too small for the actual job.

What the better teams seem to have figured out is this:

> **Prompt engineering is tactical. Context engineering is strategic.**

If you want reliable behavior, you are not really writing prompts anymore. You are designing context.

That is what this article is about.

---

## From Prompt Engineering to Context Engineering

### What Changed

**Prompt Engineering (2022-2023):**
```
Focus: Crafting the perfect single prompt
Goal: Get the right output
Mindset: "What should I ask?"
Skill: Wording, examples, formatting
```

**Context Engineering (2024+):**
```
Focus: Designing the entire information environment
Goal: Create reliable, scalable AI behavior
Mindset: "What context does the AI need?"
Skill: Architecture, information design, system thinking
```

### The Evolution

```
┌─────────────────────────────────────────────────────────────┐
│              Evolution of AI Programming                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Phase 1: Prompt Engineering                                │
│  ┌─────────────────────────────────────────────┐           │
│  │ "Write a function to sort users by name"    │           │
│  │ → Single prompt, hope for best              │           │
│  └─────────────────────────────────────────────┘           │
│                                                             │
│  Phase 2: Prompt + Examples                                 │
│  ┌─────────────────────────────────────────────┐           │
│  │ System: You are a coding assistant          │           │
│  │ User: Sort users                            │           │
│  │ Examples: [input → output pairs]            │           │
│  └─────────────────────────────────────────────┘           │
│                                                             │
│  Phase 3: Context Engineering                               │
│  ┌─────────────────────────────────────────────┐           │
│  │ System Role: Senior Python developer        │           │
│  │ Project Context: Django app, specific style │           │
│  │ Conversation History: Previous decisions    │           │
│  │ Knowledge Base: Project docs, APIs          │           │
│  │ Tools Available: Linter, tests, formatter   │           │
│  │ User Preferences: Concise, production-ready │           │
│  │ Current Task: Sort users by name            │           │
│  └─────────────────────────────────────────────┘           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### The Key Insight

> **Context is the new code.**

That line can sound a little dramatic, but I think it is directionally right.

In traditional programming, you write logic. In AI programming, a lot of the real work shifts toward designing the information environment that shapes behavior.

---

## The Context Stack: Layers of Information

Think of context as a stack of layers, each serving a different purpose:

```
┌─────────────────────────────────────────┐
│           The Context Stack             │
├─────────────────────────────────────────┤
│  Layer 5: Task Context (Current)        │
│  - Specific request                     │
│  - Immediate parameters                 │
│  - Current conversation turn            │
├─────────────────────────────────────────┤
│  Layer 4: Conversation Context          │
│  - Session history                      │
│  - Previous decisions                   │
│  - User preferences                     │
├─────────────────────────────────────────┤
│  Layer 3: Knowledge Context (RAG)       │
│  - Relevant documents                   │
│  - Domain information                   │
│  - Retrieved facts                      │
├─────────────────────────────────────────┤
│  Layer 2: Instruction Context           │
│  - System instructions                  │
│  - Behavioral constraints               │
│  - Output format requirements           │
├─────────────────────────────────────────┤
│  Layer 1: Identity Context              │
│  - Role definition                      │
│  - Capabilities                         │
│  - Relationship to user                 │
└─────────────────────────────────────────┘
```

Let's examine each layer.

---

## Layer 1: Identity Context

### What It Is

Identity context defines **who the AI is** in this interaction.

### Components

```python
identity_context = {
    "role": "Senior software architect",
    "expertise": ["system design", "Python", "distributed systems"],
    "relationship": "Collaborative advisor, not order-taker",
    "personality": "Direct, practical, questions assumptions",
    "constraints": "Does not write code without understanding requirements"
}
```

### Implementation

```python
def build_identity_context(scenario):
    """Build identity context for the scenario."""
    
    scenarios = {
        "code_review": {
            "role": "Senior code reviewer",
            "focus": ["correctness", "readability", "performance", "security"],
            "style": "Constructive, specific, actionable",
            "output_format": "Issue → Location → Suggestion → Example"
        },
        "architecture_design": {
            "role": "Principal architect",
            "focus": ["scalability", "maintainability", "trade-offs"],
            "style": "Analytical, explores alternatives",
            "output_format": "Requirements → Options → Recommendation → Rationale"
        },
        "debugging": {
            "role": "Debugging specialist",
            "focus": ["root cause", "reproduction", "fix"],
            "style": "Systematic, hypothesis-driven",
            "output_format": "Symptom → Hypothesis → Test → Fix"
        }
    }
    
    return scenarios.get(scenario, scenarios["code_review"])
```

### Best Practices

**Do:**
- Be specific about role and expertise level
- Define the relationship dynamic
- Set personality expectations

**Don't:**
- Be vague ("You are a helpful assistant")
- Over-constrain ("You must always...")
- Contradict ("Be creative but follow rules strictly")

---

## Layer 2: Instruction Context

### What It Is

Instruction context defines **how the AI should behave** and **what rules to follow**.

### Components

```python
instruction_context = """
BEHAVIORAL GUIDELINES:
- Ask clarifying questions when requirements are ambiguous
- Explain reasoning before giving answers
- Acknowledge uncertainty when present

OUTPUT REQUIREMENTS:
- Code must include type hints
- Functions must have docstrings
- Include tests for new functionality

CONSTRAINTS:
- Do not use external libraries without permission
- Prefer readability over cleverness
- Flag potential security issues
"""
```

### Implementation

```python
class InstructionBuilder:
    def __init__(self):
        self.instructions = []
        self.constraints = []
        self.format_requirements = []
    
    def add_instruction(self, instruction):
        self.instructions.append(instruction)
        return self
    
    def add_constraint(self, constraint):
        self.constraints.append(constraint)
        return self
    
    def add_format_requirement(self, requirement):
        self.format_requirements.append(requirement)
        return self
    
    def build(self):
        sections = []
        
        if self.instructions:
            sections.append("INSTRUCTIONS:\n" + "\n".join(f"- {i}" for i in self.instructions))
        
        if self.constraints:
            sections.append("CONSTRAINTS:\n" + "\n".join(f"- {c}" for c in self.constraints))
        
        if self.format_requirements:
            sections.append("OUTPUT FORMAT:\n" + "\n".join(f"- {f}" for f in self.format_requirements))
        
        return "\n\n".join(sections)


# Usage
instructions = (InstructionBuilder()
    .add_instruction("Think step-by-step before answering")
    .add_instruction("Cite sources when making factual claims")
    .add_constraint("Never expose API keys or secrets")
    .add_constraint("Do not make assumptions about user intent")
    .add_format_requirement("Use markdown code blocks for all code")
    .add_format_requirement("Include complexity analysis for algorithms")
    .build())
```

---

## Layer 3: Knowledge Context (RAG)

### What It Is

Knowledge context provides **domain-specific information** the AI needs to answer accurately.

### Components

```python
knowledge_context = {
    "project_docs": "API documentation, architecture decisions",
    "codebase_info": "Existing patterns, conventions, utilities",
    "business_logic": "Domain rules, constraints, terminology",
    "retrieved_facts": "Information retrieved based on current query"
}
```

### Implementation

```python
class KnowledgeContextManager:
    def __init__(self, vector_db, embedding_model):
        self.vector_db = vector_db
        self.embedding_model = embedding_model
    
    def build_context(self, query, project_id, max_tokens=2000):
        """Build knowledge context for a query."""
        
        # 1. Embed the query
        query_embedding = self.embedding_model.encode(query)
        
        # 2. Retrieve relevant documents
        results = self.vector_db.similarity_search(
            query_embedding,
            filter={"project_id": project_id},
            top_k=10
        )
        
        # 3. Rank and select
        ranked = self.rerank_results(results, query)
        selected = self.select_within_token_limit(ranked, max_tokens)
        
        # 4. Format for LLM
        context = self.format_context(selected)
        
        return context
    
    def rerank_results(self, results, query):
        """Rerank results by relevance."""
        # Use cross-encoder or other reranking strategy
        return sorted(results, key=lambda r: r.relevance_score, reverse=True)
    
    def select_within_token_limit(self, results, max_tokens):
        """Select results that fit within token budget."""
        selected = []
        tokens = 0
        
        for result in results:
            result_tokens = count_tokens(result.text)
            if tokens + result_tokens <= max_tokens:
                selected.append(result)
                tokens += result_tokens
        
        return selected
    
    def format_context(self, results):
        """Format results as context for LLM."""
        sections = []
        
        for i, result in enumerate(results, 1):
            sections.append(f"""
[Source {i}: {result.metadata['source']}]
{result.text}
""")
        
        return "\n".join(sections)
```

---

## Layer 4: Conversation Context

### What It Is

Conversation context provides **continuity** across the interaction.

### Components

```python
conversation_context = {
    "history": "Previous messages in this session",
    "decisions": "Decisions made during conversation",
    "preferences": "User preferences discovered",
    "pending_tasks": "Unfinished work items",
    "state": "Current task state"
}
```

### Implementation

```python
class ConversationContextManager:
    def __init__(self, session_id, max_tokens=4000):
        self.session_id = session_id
        self.max_tokens = max_tokens
        self.messages = []
        self.decisions = []
        self.user_preferences = {}
    
    def add_message(self, role, content):
        """Add a message to conversation history."""
        self.messages.append({
            "role": role,
            "content": content,
            "timestamp": datetime.now()
        })
    
    def record_decision(self, decision):
        """Record a decision made during conversation."""
        self.decisions.append({
            "decision": decision,
            "timestamp": datetime.now()
        })
    
    def set_preference(self, key, value):
        """Set a user preference."""
        self.user_preferences[key] = value
    
    def build_context(self):
        """Build conversation context for LLM."""
        context_parts = []
        
        # 1. Decisions summary
        if self.decisions:
            decisions_text = "\n".join(f"- {d['decision']}" for d in self.decisions)
            context_parts.append(f"DECISIONS MADE:\n{decisions_text}")
        
        # 2. User preferences
        if self.user_preferences:
            prefs_text = "\n".join(f"- {k}: {v}" for k, v in self.user_preferences.items())
            context_parts.append(f"USER PREFERENCES:\n{prefs_text}")
        
        # 3. Message history (within token limit)
        history = self._build_message_history()
        if history:
            context_parts.append(f"CONVERSATION:\n{history}")
        
        return "\n\n".join(context_parts)
    
    def _build_message_history(self):
        """Build message history within token limit."""
        messages = []
        tokens = 0
        
        for msg in reversed(self.messages):
            msg_tokens = count_tokens(msg["content"])
            if tokens + msg_tokens > self.max_tokens:
                break
            messages.insert(0, f"{msg['role']}: {msg['content']}")
            tokens += msg_tokens
        
        return "\n".join(messages)
```

---

## Layer 5: Task Context

### What It Is

Task context is the **immediate request**—what the user wants right now.

### Components

```python
task_context = {
    "request": "The specific ask",
    "parameters": "Arguments and inputs",
    "constraints": "Task-specific constraints",
    "success_criteria": "What good looks like"
}
```

### Implementation

```python
class TaskContextBuilder:
    def __init__(self):
        self.request = None
        self.parameters = {}
        self.constraints = []
        self.success_criteria = []
    
    def set_request(self, request):
        self.request = request
        return self
    
    def add_parameter(self, key, value):
        self.parameters[key] = value
        return self
    
    def add_constraint(self, constraint):
        self.constraints.append(constraint)
        return self
    
    def add_success_criterion(self, criterion):
        self.success_criteria.append(criterion)
        return self
    
    def build(self):
        parts = []
        
        if self.request:
            parts.append(f"TASK: {self.request}")
        
        if self.parameters:
            params_text = "\n".join(f"- {k}: {v}" for k, v in self.parameters.items())
            parts.append(f"PARAMETERS:\n{params_text}")
        
        if self.constraints:
            parts.append(f"CONSTRAINTS:\n" + "\n".join(f"- {c}" for c in self.constraints))
        
        if self.success_criteria:
            parts.append(f"SUCCESS CRITERIA:\n" + "\n".join(f"- {s}" for s in self.success_criteria))
        
        return "\n\n".join(parts)


# Usage
task = (TaskContextBuilder()
    .set_request("Refactor the user authentication module")
    .add_parameter("current_file", "auth.py")
    .add_parameter("lines", "50-200")
    .add_constraint("Maintain backward compatibility")
    .add_constraint("No breaking changes to API")
    .add_success_criterion("Reduced cyclomatic complexity")
    .add_success_criterion("Improved test coverage")
    .add_success_criterion("Clear separation of concerns")
    .build())
```

---

## Putting It All Together: The Context Orchestrator

```python
class ContextOrchestrator:
    """Orchestrates all context layers for AI interactions."""
    
    def __init__(self, config):
        self.identity_builder = IdentityContextBuilder(config["identities"])
        self.instruction_builder = InstructionBuilder()
        self.knowledge_manager = KnowledgeContextManager(
            config["vector_db"],
            config["embedding_model"]
        )
        self.conversation_manager = ConversationContextManager(
            config["session_id"]
        )
        self.task_builder = TaskContextBuilder()
        
        self.token_budget = config.get("token_budget", 8000)
    
    def build_full_context(self, request, metadata):
        """Build complete context for an AI interaction."""
        
        context_layers = []
        tokens_used = 0
        
        # Layer 1: Identity
        identity = self.identity_builder.build(metadata.get("scenario"))
        context_layers.append(identity)
        tokens_used += count_tokens(identity)
        
        # Layer 2: Instructions
        instructions = self._build_instructions_for_scenario(metadata.get("scenario"))
        context_layers.append(instructions)
        tokens_used += count_tokens(instructions)
        
        # Layer 3: Knowledge (if needed)
        if metadata.get("needs_knowledge"):
            remaining_tokens = self.token_budget - tokens_used - 1000  # Reserve for other layers
            knowledge = self.knowledge_manager.build_context(
                request,
                metadata.get("project_id"),
                max_tokens=remaining_tokens
            )
            context_layers.append(knowledge)
            tokens_used += count_tokens(knowledge)
        
        # Layer 4: Conversation
        conversation = self.conversation_manager.build_context()
        if conversation:
            context_layers.append(conversation)
            tokens_used += count_tokens(conversation)
        
        # Layer 5: Task
        task = self._build_task_context(request, metadata)
        context_layers.append(task)
        
        # Combine all layers
        full_context = "\n\n---\n\n".join(context_layers)
        
        # Verify within budget
        final_tokens = count_tokens(full_context)
        if final_tokens > self.token_budget:
            raise ContextOverflowError(f"Context exceeds token budget: {final_tokens}/{self.token_budget}")
        
        return full_context
    
    def _build_instructions_for_scenario(self, scenario):
        """Build scenario-specific instructions."""
        # Implementation depends on your scenarios
        pass
    
    def _build_task_context(self, request, metadata):
        """Build task context from request."""
        builder = TaskContextBuilder()
        builder.set_request(request)
        
        for key, value in metadata.get("parameters", {}).items():
            builder.add_parameter(key, value)
        
        for constraint in metadata.get("constraints", []):
            builder.add_constraint(constraint)
        
        return builder.build()
```

---

## Context Engineering Patterns

### Pattern 1: Progressive Disclosure

```python
def build_progressive_context(initial_request, conversation):
    """Start minimal, add context as needed."""
    
    # Start with just the request
    context = f"Task: {initial_request}"
    
    # If conversation continues, add history
    if len(conversation) > 1:
        context += f"\n\nConversation History:\n{format_history(conversation)}"
    
    # If ambiguity detected, add clarifying context
    if detect_ambiguity(initial_request):
        context += "\n\nNote: If requirements are unclear, ask clarifying questions."
    
    return context
```

**Use when:** Token budget is tight, or you want to minimize context noise.

---

### Pattern 2: Context Templates

```python
CONTEXT_TEMPLATES = {
    "code_review": """
ROLE: Senior code reviewer
FOCUS: Correctness, readability, security

INSTRUCTIONS:
- Review the code systematically
- Identify issues with severity levels
- Suggest specific improvements

FORMAT:
[Severity] Issue: Description
Suggestion: Fix
Example: Code
""",

    "debugging": """
ROLE: Debugging specialist
APPROACH: Hypothesis-driven

INSTRUCTIONS:
- Analyze symptoms
- Generate hypotheses
- Suggest tests
- Propose fixes

FORMAT:
Symptom → Hypothesis → Test → Fix
"""
}

def use_template(scenario, variables):
    """Use a context template with variables."""
    template = CONTEXT_TEMPLATES.get(scenario)
    return template.format(**variables)
```

**Use when:** You have recurring scenarios with consistent context needs.

---

### Pattern 3: Context Chaining

```python
def chain_contexts(initial_context, llm_response, follow_up_request):
    """Chain context across multiple interactions."""
    
    # Extract key information from previous exchange
    summary = llm.generate(f"""
    Summarize the key decisions and outcomes from this exchange:
    
    Context: {initial_context}
    Response: {llm_response}
    
    Summary (2-3 sentences):
    """)
    
    # Build new context with summary
    new_context = f"""
    PREVIOUS SESSION SUMMARY:
    {summary}
    
    CURRENT REQUEST:
    {follow_up_request}
    """
    
    return new_context
```

**Use when:** Conversations span multiple sessions or have natural breakpoints.

---

## Context Quality Metrics

How do you know if your context engineering is working?

```python
class ContextQualityMetrics:
    def __init__(self):
        self.metrics = {}
    
    def measure(self, context, llm_output, user_feedback):
        """Measure context quality."""
        
        self.metrics["completeness"] = self.measure_completeness(context, llm_output)
        self.metrics["relevance"] = self.measure_relevance(context, llm_output)
        self.metrics["efficiency"] = self.measure_efficiency(context)
        self.metrics["satisfaction"] = self.measure_satisfaction(user_feedback)
        
        return self.metrics
    
    def measure_completeness(self, context, output):
        """Did the context provide enough information?"""
        # Check if output indicates missing information
        phrases = ["I don't have enough information", "Could you provide", "unclear"]
        return not any(phrase in output.lower() for phrase in phrases)
    
    def measure_relevance(self, context, output):
        """Was the context relevant to the task?"""
        # Check if output uses provided context
        context_terms = extract_key_terms(context)
        output_terms = extract_key_terms(output)
        return len(set(context_terms) & set(output_terms)) / len(context_terms)
    
    def measure_efficiency(self, context):
        """Is context token-efficient?"""
        tokens = count_tokens(context)
        # Lower is better (assuming quality is maintained)
        return 1.0 / (tokens / 1000)
    
    def measure_satisfaction(self, feedback):
        """User satisfaction score."""
        return feedback.rating / 5.0
```

---

## Key Takeaways

- **Context engineering > Prompt engineering**. Design the entire information environment, not just the prompt.
- **The Context Stack has 5 layers**: Identity, Instructions, Knowledge, Conversation, Task.
- **Each layer serves a purpose**: Identity (who), Instructions (how), Knowledge (what info), Conversation (continuity), Task (current ask).
- **Orchestrate context systematically**: Use a ContextOrchestrator to manage all layers.
- **Measure context quality**: Completeness, relevance, efficiency, satisfaction.

---

## Next Article

In **Article 7: From Logic-Driven to Context-Driven Software**, we'll explore how this shift to context engineering represents a fundamental paradigm change in software development. We'll compare traditional logic-driven programming with the new context-driven approach.

---

*This is the sixth article in the **"Software Engineering in the LLM Era"** series. [Read previous articles](/categories/series/).*

---

💬 **What's your experience with context engineering? Share your patterns and challenges in the comments!** 🚀
