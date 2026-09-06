---
layout: post
title: "From Logic-Driven to Context-Driven Software"
description: "How software built by encoding explicit rules is giving way to software built by shaping context, and what that changes about the engineering job."
date: "2026-02-28"
categories: [AI]
series: "Software Engineering in the LLM Era"
tags: [llm, ai, agents]
---
<audio controls preload="metadata" src="/assets/audio/logic-driven-to-context-driven-software-summary.ogg">
  Your browser does not support the audio element.
</audio>


If you have been an engineer for long enough, you probably built your instincts around things like:

- Decomposing problems into algorithms
- Writing clean, maintainable code
- Designing scalable architectures
- Debugging complex systems

Then AI shows up and starts messing with those instincts:

- Your code generates itself (mostly)
- Your tests pass, but you're not sure why
- Your system works, but behaves differently each time
- Your debugging skills don't apply to probabilistic failures

That is the shift a lot of people are feeling:

> **We're moving from logic-driven software to context-driven software.**

I do not think this means logic-driven software disappears. But I do think a second mode of building has arrived, and it changes what good engineering work looks like.

---

## The Two Paradigms

### Logic-Driven Software (1950s-2020s)

Core principle: explicitly encode all rules and behaviors. Input flows through explicit logic to produce output. The engineer's job is to define every rule, handle every case, anticipate every edge case, and write deterministic code.

```python
def calculate_discount(order):
    if order.total > 1000:
        if order.customer.vip:
            return 0.20
        return 0.10
    elif order.total > 500:
        return 0.05
    return 0.00
```

This is deterministic (same input, same output), explicit (every rule is visible in the code), and testable (every path can be verified). The cost is that it's brittle, it breaks on unhandled cases, and it's labor-intensive: every rule has to be written by hand.

### Context-Driven Software (2020s-)

Core principle: provide context, let the system infer behavior. Input plus context flows through an inference engine to produce output. The engineer's job shifts to designing the context environment, curating examples and constraints, defining success criteria, and validating outputs.

```python
context = build_context(
    role="pricing assistant",
    examples=[vip_examples, standard_examples],
    constraints=["never exceed 20% discount"],
    knowledge=[pricing_policy_docs]
)
response = llm.generate(context + order_info)
```

This is flexible (it handles novel cases) and concise (less code to write). The cost is that it's probabilistic (the output varies) and implicit (the behavior isn't fully visible in the code).

---

## The Fundamental Shift

| Aspect | Logic-Driven | Context-Driven |
|--------|-------------|----------------|
| **Control** | Direct (code every rule) | Indirect (shape behavior) |
| **Specificity** | Exact (precise instructions) | Fuzzy (guidance + inference) |
| **Handling Novelty** | Breaks (unhandled cases) | Adapts (generalizes) |
| **Engineer's Focus** | Implementation | Curation + Validation |
| **Testing** | Verify all paths | Sample + validate patterns |
| **Debugging** | Trace execution | Analyze context + patterns |
| **Documentation** | Comments + docs | Context + examples |

The mental shift is from "how do I code this behavior?" (write algorithms, handle edge cases, test exhaustively) to "what context produces this behavior?" (design the information environment, curate examples, validate outputs).

That shift is easy to say and harder to feel. It becomes clearer with examples.

## Concrete Examples: Before and After

### Example 1: Customer Support Routing

Logic-driven, this looks like a keyword-matching rule tree:

```python
def route_support_ticket(ticket):
    keywords = extract_keywords(ticket.text)

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

    return "general_support"
```

It misses novel phrasing, needs constant rule updates, and can't handle ambiguity gracefully.

Context-driven, the routing logic moves into the prompt:

```python
def route_support_ticket(ticket):
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
            "VIP customers -> priority routing",
            "Critical issues -> engineering immediately",
            "When uncertain, route to general_support"
        ]
    )

    return llm.generate(f"""
    {context}

    Ticket: {ticket.text}
    Customer: VIP={ticket.customer.vip}, Priority={ticket.priority}

    Route to team:
    """)
```

This handles novel phrasing and language variation because it's matching on meaning, not keywords. The trade-off is you can no longer point at a line of code and say exactly why a given ticket went where it went.

### Example 2: Data Validation

Logic-driven validation grows linearly with every rule and every country you support:

```python
def validate_user_data(data):
    errors = []

    if not data.get("name"):
        errors.append("Name is required")
    elif len(data["name"]) < 2:
        errors.append("Name must be at least 2 characters")
    elif not re.match(r"^[a-zA-Z\s'-]+$", data["name"]):
        errors.append("Name contains invalid characters")

    if not data.get("email"):
        errors.append("Email is required")
    elif not re.match(r"^[^@]+@[^@]+\.[^@]+$", data["email"]):
        errors.append("Invalid email format")

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
```

It's an enormous rule set that's hard to maintain and still misses edge cases.

{% raw %}
```python
def validate_user_data(data, country="US"):
    context = build_context(
        role="Data validation specialist",
        knowledge=[
            f"Validation rules for {country}",
            "Common data quality issues",
            "Privacy and compliance requirements"
        ],
        instructions=[
            "Validate all fields for correctness and completeness",
            "Flag suspicious patterns (potential fraud)",
            "Be lenient on format, strict on substance"
        ],
        examples=[
            ({"name": "J", "email": "test@test.com"},
             "Name seems too short, possible data quality issue"),
            ({"email": "user@tempmail.com"},
             "Disposable email domain, flag for review"),
        ]
    )

    response = llm.generate(f"""
    {context}

    Data to validate:
    {json.dumps(data)}

    Validation results (JSON): {{"valid": true/false, "errors": [...], "warnings": [...], "flags": [...]}}
    """)

    return json.loads(response)
```
{% endraw %}

This version handles format variation gracefully and can flag suspicious patterns a fixed regex would never catch. It also means validation is no longer deterministic: the same input can, in principle, get a different verdict on a different run, which is a real cost for anything security- or compliance-adjacent.

---

## The Engineering Skill Shift

Skills that become less differentiating: memorizing APIs and syntax, writing boilerplate, manually debugging routine issues, encoding business rules as if-statements, writing exhaustive test cases for every path. AI can generate or assist with all of these directly.

Skills that become more critical:

- **Context design.** Crafting effective information environments, selecting relevant examples, structuring constraints.
- **Output validation.** Designing validation systems, recognizing plausible-but-wrong outputs, building safety nets.
- **System architecture.** Knowing when to use AI versus traditional code, designing hybrid systems, managing probabilistic components.
- **Domain expertise.** Understanding what "good" looks like, recognizing edge cases, curating quality examples.
- **Debugging context.** Diagnosing why a given context produces the wrong output, iterating on context design, understanding failure modes.

The table above already captures the shape of this: more time on curation and validation, less on hand-written implementation.

---

## The Hybrid Approach

The future isn't purely context-driven. It's hybrid: context-driven components (understanding, generation, reasoning, flexibility) and logic-driven components (computation, validation, determinism, precision) both feed into an orchestrator, which is still your code, routing tasks, validating results, and combining them.

{% raw %}
```python
class HybridDataProcessor:
    """Combine LLM understanding with deterministic processing."""

    def __init__(self):
        self.llm = LLMComponent()
        self.validator = DataValidator()
        self.processor = DeterministicProcessor()

    def process_request(self, user_request):
        # LLM understands intent (context-driven)
        intent = self.llm.generate(f"""
        Extract the user's intent and parameters from this request.
        Request: {user_request}
        Output JSON: {{"intent": "...", "parameters": {{...}}, "constraints": [...]}}
        """)

        # Validate extracted information (logic-driven)
        if not self.validator.validate_intent(intent):
            return self.handle_error("Could not understand request")

        # Execute deterministically (logic-driven)
        result = self.processor.execute(intent["intent"], intent["parameters"])

        # LLM formats the response (context-driven)
        return self.llm.generate(f"""
        Format this result as a helpful response to the user.
        Original request: {user_request}
        Result: {result}
        """)
```
{% endraw %}

Logic-driven software isn't going away. Most reliable systems I've seen still want deterministic code for anything that touches money, security, or compliance. What's changed is that a second mode now exists alongside it, and the interesting design work is figuring out which parts of a system belong in which mode, not picking one over the other.
