---
layout: post
title: "From Logic-Driven to Context-Driven Software"
date: "2026-02-28"
categories: LLM AI software-engineering series
series: "Software Engineering in the LLM Era"
---

## The Problem

You're a senior engineer with 15 years of experience. You've mastered:

- Decomposing problems into algorithms
- Writing clean, maintainable code
- Designing scalable architectures
- Debugging complex systems

Then AI comes along, and suddenly...

- Your code generates itself (mostly)
- Your tests pass, but you're not sure why
- Your system works, but behaves differently each time
- Your debugging skills don't apply to probabilistic failures

You're experiencing the paradigm shift:

> **We're moving from logic-driven software to context-driven software.**

This isn't an incremental change. It's a fundamental shift in how we think about building systems. In this article, we'll explore what this means for you as an engineer.

---

## The Two Paradigms

### Logic-Driven Software (1950s-2020s)

```
┌─────────────────────────────────────────────────────────────┐
│              Logic-Driven Software                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Core Principle:                                            │
│  "Explicitly encode all rules and behaviors"                │
│                                                             │
│  Flow:                                                      │
│  Input → [Explicit Logic] → Output                          │
│                                                             │
│  Engineer's Role:                                           │
│  - Define every rule                                        │
│  - Handle every case                                        │
│  - Anticipate every edge case                               │
│  - Write deterministic code                                 │
│                                                             │
│  Example:                                                   │
│  def calculate_discount(order):                             │
│      if order.total > 1000:                                 │
│          if order.customer.vip:                             │
│              return 0.20                                    │
│          return 0.10                                        │
│      elif order.total > 500:                                │
│          return 0.05                                        │
│      return 0.00                                            │
│                                                             │
│  Properties:                                                │
│  ✓ Deterministic (same input → same output)                 │
│  ✓ Explicit (all rules visible in code)                     │
│  ✓ Testable (every path can be verified)                    │
│   brittle (breaks on unhandled cases)                       │
│   Labor-intensive (every rule must be written)              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Context-Driven Software (2020s-)

```
┌─────────────────────────────────────────────────────────────┐
│             Context-Driven Software                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Core Principle:                                            │
│  "Provide context; let the system infer behavior"           │
│                                                             │
│  Flow:                                                      │
│  Input + Context → [Inference Engine] → Output              │
│                                                             │
│  Engineer's Role:                                           │
│  - Design context environment                               │
│  - Curate examples and constraints                          │
│  - Define success criteria                                  │
│  - Validate and guide outputs                               │
│                                                             │
│  Example:                                                   │
│  context = build_context(                                   │
│      role="pricing assistant",                              │
│      examples=[vip_examples, standard_examples],            │
│      constraints=["never exceed 20% discount"],             │
│      knowledge=[pricing_policy_docs]                        │
│  )                                                          │
│  response = llm.generate(context + order_info)              │
│                                                             │
│  Properties:                                                │
│  ✓ Flexible (handles novel cases)                           │
│  ✓ Adaptive (learns from examples)                          │
│  ✓ Concise (less code to write)                             │
│   Probabilistic (output varies)                             │
│   Implicit (behavior not fully visible)                     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## The Fundamental Shift

### What Changed

| Aspect | Logic-Driven | Context-Driven |
|--------|-------------|----------------|
| **Control** | Direct (code every rule) | Indirect (shape behavior) |
| **Specificity** | Exact (precise instructions) | Fuzzy (guidance + inference) |
| **Handling Novelty** | Breaks (unhandled cases) | Adapts (generalizes) |
| **Engineer's Focus** | Implementation | Curation + Validation |
| **Testing** | Verify all paths | Sample + validate patterns |
| **Debugging** | Trace execution | Analyze context + patterns |
| **Documentation** | Comments + docs | Context + examples |

### The Mental Shift

```
Logic-Driven Mindset:
"How do I code this behavior?"
→ Write algorithms
→ Handle edge cases
→ Test exhaustively

Context-Driven Mindset:
"What context produces this behavior?"
→ Design information environment
→ Curate examples
→ Validate outputs
```

---

## Concrete Examples: Before and After

### Example 1: Customer Support Routing

**Logic-Driven (Traditional):**

```python
def route_support_ticket(ticket):
    """Route support tickets based on explicit rules."""
    
    # Extract keywords
    keywords = extract_keywords(ticket.text)
    
    # Rule-based routing
    if any(k in keywords for k in ["billing", "invoice", "payment"]):
        if "refund" in keywords:
            if ticket.customer.vip:
                return "vip_billing_team"
            return "billing_team"
        return "payments_team"
    
    elif any(k in keywords for k in ["bug", "error", "broken"]):
        if "critical" in ticket.priority:
            return "critical_engineering"
        if any(k in keywords for k in ["login", "auth"]):
            return "auth_team"
        return "engineering_team"
    
    elif any(k in keywords for k in ["feature", "request", "suggestion"]):
        return "product_team"
    
    # Default fallback
    return "general_support"


# Problems:
# - Misses novel phrasings
# - Requires constant rule updates
# - Brittle to language variations
# - Hard to handle ambiguity
```

**Context-Driven (AI):**

```python
def route_support_ticket(ticket):
    """Route support tickets using context-driven AI."""
    
    context = build_context(
        role="Support routing specialist",
        knowledge=[
            "Team responsibilities document",
            "Historical routing decisions",
            "Escalation policies"
        ],
        examples=[
            ("Billing question about invoice", "billing_team"),
            ("Can't login to my account", "auth_team"),
            ("Would love to see dark mode", "product_team"),
            ("App crashes on startup", "engineering_team"),
        ],
        constraints=[
            "VIP customers → priority routing",
            "Critical issues → engineering immediately",
            "When uncertain, route to general_support"
        ]
    )
    
    response = llm.generate(f"""
    {context}
    
    Ticket: {ticket.text}
    Customer: VIP={ticket.customer.vip}, Priority={ticket.priority}
    
    Route to team:
    """)
    
    return response


# Advantages:
# + Handles novel phrasings
# + Learns from examples
# + Adapts to language variations
# + Handles ambiguity gracefully
```

---

### Example 2: Code Review

**Logic-Driven (Traditional):**

```python
def review_code(code):
    """Automated code review with explicit rules."""
    
    issues = []
    
    # Rule 1: Check line length
    for i, line in enumerate(code.split('\n'), 1):
        if len(line) > 120:
            issues.append(f"Line {i}: exceeds 120 characters")
    
    # Rule 2: Check for docstrings
    for func in find_functions(code):
        if not has_docstring(func):
            issues.append(f"Function {func.name}: missing docstring")
    
    # Rule 3: Check for type hints
    for func in find_functions(code):
        if not has_type_hints(func):
            issues.append(f"Function {func.name}: missing type hints")
    
    # Rule 4: Check for common security issues
    if "eval(" in code:
        issues.append("Security: use of eval() detected")
    
    if "SELECT * FROM" in code:
        issues.append("Performance: SELECT * detected")
    
    return issues


# Problems:
# - Only catches predefined issues
# - Misses context-specific problems
# - Can't explain WHY something is wrong
# - No suggestions for improvement
```

**Context-Driven (AI):**

```python
def review_code(code, context_info):
    """AI-powered code review with context."""
    
    context = build_context(
        role="Senior code reviewer with 15 years experience",
        knowledge=[
            context_info["project_style_guide"],
            context_info["security_policies"],
            context_info["common_patterns"]
        ],
        instructions=[
            "Review for: correctness, security, performance, readability",
            "Explain WHY each issue is a problem",
            "Suggest specific improvements with code examples",
            "Prioritize issues by severity (critical, high, medium, low)"
        ],
        examples=[
            (bad_code_1, "Security: SQL injection vulnerability..."),
            (bad_code_2, "Performance: N+1 query detected..."),
        ]
    )
    
    response = llm.generate(f"""
    {context}
    
    Code to review:
    ```{context_info['language']}
    {code}
    ```
    
    Review:
    """)
    
    return parse_review(response)


# Advantages:
# + Catches novel issues
# + Provides explanations
# + Suggests improvements
# + Adapts to project context
```

---

### Example 3: Data Validation

**Logic-Driven (Traditional):**

```python
def validate_user_data(data):
    """Validate user data with explicit rules."""
    
    errors = []
    
    # Name validation
    if not data.get("name"):
        errors.append("Name is required")
    elif len(data["name"]) < 2:
        errors.append("Name must be at least 2 characters")
    elif len(data["name"]) > 100:
        errors.append("Name must be less than 100 characters")
    elif not re.match(r"^[a-zA-Z\s'-]+$", data["name"]):
        errors.append("Name contains invalid characters")
    
    # Email validation
    if not data.get("email"):
        errors.append("Email is required")
    elif not re.match(r"^[^@]+@[^@]+\.[^@]+$", data["email"]):
        errors.append("Invalid email format")
    elif not is_domain_valid(data["email"]):
        errors.append("Email domain does not exist")
    
    # Age validation
    if data.get("age"):
        if not isinstance(data["age"], int):
            errors.append("Age must be a number")
        elif data["age"] < 0 or data["age"] > 150:
            errors.append("Age must be between 0 and 150")
    
    # Phone validation (different rules per country)
    if data.get("phone"):
        country = data.get("country", "US")
        if country == "US":
            if not re.match(r"^\d{10}$", data["phone"]):
                errors.append("US phone must be 10 digits")
        elif country == "UK":
            if not re.match(r"^\+44\d{10}$", data["phone"]):
                errors.append("UK phone format invalid")
        # ... 50 more countries
    
    return errors


# Problems:
# - Enormous rule set
# - Hard to maintain
# - Misses edge cases
# - Can't handle variations
```

**Context-Driven (AI):**

```python
def validate_user_data(data, country="US"):
    """AI-powered data validation with context."""
    
    context = build_context(
        role="Data validation specialist",
        knowledge=[
            f"Validation rules for {country}",
            "Common data quality issues",
            "Privacy and compliance requirements"
        ],
        instructions=[
            "Validate all fields for correctness and completeness",
            "Check for common data quality issues",
            "Flag suspicious patterns (potential fraud)",
            "Be lenient on format, strict on substance"
        ],
        examples=[
            ({"name": "J", "email": "test@test.com"}, 
             "Name seems too short - possible data quality issue"),
            ({"email": "user@tempmail.com"}, 
             "Disposable email domain - flag for review"),
        ]
    )
    
    response = llm.generate(f"""
    {context}
    
    Data to validate:
    {json.dumps(data)}
    
    Validation results (JSON format):
    {{
        "valid": true/false,
        "errors": [...],
        "warnings": [...],
        "flags": [...]
    }}
    """)
    
    return json.loads(response)


# Advantages:
# + Handles variations gracefully
# + Detects suspicious patterns
# + Provides contextual warnings
# + Adapts to different countries
```

---

## The Engineering Skill Shift

### Skills That Become Less Critical

```
┌─────────────────────────────────────────────────────────────┐
│           Declining Importance                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Memorizing APIs and syntax                              │
│     → AI can generate correct syntax                        │
│                                                             │
│  2. Writing boilerplate code                                │
│     → AI generates standard patterns                        │
│                                                             │
│  3. Manual debugging of routine issues                      │
│     → AI can trace and explain                              │
│                                                             │
│  4. Encoding business rules as if-statements                │
│     → AI infers from context                                │
│                                                             │
│  5. Writing exhaustive test cases for all paths             │
│     → AI helps generate, but validation shifts              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Skills That Become More Critical

```
┌─────────────────────────────────────────────────────────────┐
│           Increasing Importance                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Context Design                                          │
│     - Crafting effective information environments           │
│     - Selecting relevant examples                           │
│     - Structuring constraints                               │
│                                                             │
│  2. Output Validation                                       │
│     - Designing validation systems                          │
│     - Recognizing plausible-but-wrong outputs               │
│     - Building safety nets                                  │
│                                                             │
│  3. System Architecture                                     │
│     - Knowing when to use AI vs. traditional code           │
│     - Designing hybrid systems                              │
│     - Managing probabilistic components                     │
│                                                             │
│  4. Domain Expertise                                        │
│     - Understanding what "good" looks like                  │
│     - Recognizing edge cases                                │
│     - Curating quality examples                             │
│                                                             │
│  5. Debugging Context                                       │
│     - Diagnosing why context produces wrong outputs         │
│     - Iterating on context design                           │
│     - Understanding failure modes                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## The New Development Workflow

### Traditional Workflow

```
┌─────────────────────────────────────────────────────────────┐
│          Traditional Development Workflow                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Requirements → Understand what to build                 │
│  2. Design → Plan the architecture                          │
│  3. Implement → Write the code                              │
│  4. Test → Verify correctness                               │
│  5. Deploy → Release to production                          │
│  6. Maintain → Fix bugs, add features                       │
│                                                             │
│  Time Distribution:                                         │
│  ████████████████████░░░░░░░░░░░░░░░░░░░░ 40% Implementation│
│  ████████████████░░░░░░░░░░░░░░░░░░░░░░░░ 30% Testing      │
│  ██████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 20% Design       │
│  █████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 10% Requirements │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Context-Driven Workflow

```
┌─────────────────────────────────────────────────────────────┐
│         Context-Driven Development Workflow                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Requirements → Understand what to build                 │
│  2. Context Design → Design information environment         │
│  3. Example Curation → Select/generate quality examples     │
│  4. Constraint Definition → Set boundaries and rules        │
│  5. Validation Design → Build output verification           │
│  6. Generate → AI produces implementation                   │
│  7. Validate → Verify outputs meet criteria                 │
│  8. Iterate → Refine context based on results               │
│                                                             │
│  Time Distribution:                                         │
│  ██████████████████████████░░░░░░░░░░░░░░ 40% Context Design│
│  ████████████████░░░░░░░░░░░░░░░░░░░░░░░░ 25% Validation   │
│  ██████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 15% Examples     │
│  █████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ 10% Requirements │
│  ███░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  5% Generation   │
│  ██████████████████████████████████████████ 5% Iteration   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## The Hybrid Approach: Best of Both Worlds

The future isn't purely context-driven. It's **hybrid**:

```
┌─────────────────────────────────────────────────────────────┐
│              Hybrid Architecture                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                │
│  │  Context-Driven │    │   Logic-Driven  │                │
│  │     (LLM)       │    │  (Traditional)  │                │
│  │                 │    │                 │                │
│  │  - Understanding│    │  - Computation  │                │
│  │  - Generation   │    │  - Validation   │                │
│  │  - Reasoning    │    │  - Deterministic│                │
│  │  - Flexibility  │    │  - Precision    │                │
│  └────────┬────────┘    └────────┬────────┘                │
│           │                     │                          │
│           └──────────┬──────────┘                          │
│                      ↓                                     │
│           ┌───────────────────┐                           │
│           │  Orchestrator     │                           │
│           │  (Your Code)      │                           │
│           │                   │                           │
│           │  - Routes tasks   │                           │
│           │  - Validates      │                           │
│           │  - Combines       │                           │
│           └───────────────────┘                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Hybrid Pattern Example

```python
class HybridDataProcessor:
    """Combine LLM understanding with deterministic processing."""
    
    def __init__(self):
        self.llm = LLMComponent()
        self.validator = DataValidator()
        self.processor = DeterministicProcessor()
    
    def process_request(self, user_request):
        """Process a user request using hybrid approach."""
        
        # Step 1: LLM understands intent (context-driven)
        intent = self.llm.generate(f"""
        Extract the user's intent and parameters from this request.
        
        Request: {user_request}
        
        Output JSON:
        {{
            "intent": "...",
            "parameters": {{...}},
            "constraints": [...]
        }}
        """)
        
        # Step 2: Validate extracted information (logic-driven)
        if not self.validator.validate_intent(intent):
            return self.handle_error("Could not understand request")
        
        # Step 3: Execute deterministically (logic-driven)
        result = self.processor.execute(
            intent["intent"],
            intent["parameters"]
        )
        
        # Step 4: LLM formats response (context-driven)
        response = self.llm.generate(f"""
        Format this result as a helpful response to the user.
        
        Original request: {user_request}
        Result: {result}
        
        Response:
        """)
        
        return response
```

---

## Key Takeaways

- **Paradigm shift**: We're moving from logic-driven (encode all rules) to context-driven (provide context, infer behavior).
- **Different skills**: Context design, output validation, and system architecture become more important than manual implementation.
- **Hybrid is the future**: Combine LLM flexibility with deterministic reliability.
- **Workflow changes**: More time on context design and validation, less on implementation.
- **Mindset shift**: From "How do I code this?" to "What context produces this?"

---

## Next Article

In **Article 8: AI's Impact on the Software Development Lifecycle**, we'll explore how AI is transforming each stage of software development—from requirements gathering to maintenance. We'll examine what changes, what stays the same, and how to adapt your process.

---

*This is the seventh article in the **"Software Engineering in the LLM Era"** series. [Read previous articles](/categories/series/).*

---

💬 **How has AI changed your approach to software development? Are you designing context or writing logic? Share your experiences!** 🚀
