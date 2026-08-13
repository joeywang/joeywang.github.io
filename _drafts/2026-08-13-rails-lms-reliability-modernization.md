---
layout: post
title: "When a Rails or LMS Platform Becomes Hard to Change"
description: "A practical way for small education and SaaS teams to diagnose platform friction before committing to a rewrite."
date: 2026-08-13 09:00:00 +0100
author: "Joey Wang"
tags: [ruby-on-rails, lms, software-architecture, performance, reliability]
categories: [Engineering]
---

A platform rarely becomes difficult to change in one dramatic event. More often, the friction arrives gradually:

- A small feature needs several weeks of investigation.
- A report or export blocks a web request.
- Background jobs fail without enough evidence to explain why.
- A database query is fast in development but painful in production.
- Nobody is confident which part of the system can be changed safely.
- A proposed rewrite sounds attractive because the current system is hard to understand.

For a small education or SaaS team, these symptoms create a difficult choice. Keep adding features and accept the growing cost, or pause delivery and attempt a large modernization project with uncertain scope.

In many cases, the best first step is neither. It is a bounded investigation that separates the real constraints from the stories the team has started telling itself about the system.

## Start with friction, not technology

“Legacy Rails application” is not yet a diagnosis. It describes an age or technology choice, but not the business problem.

A useful investigation starts with questions such as:

- Which user or operational workflow is being delayed?
- How often does the problem happen?
- What does the delay cost in staff time, customer experience, or missed delivery?
- Which part of the workflow is measurable today?
- What has already been tried?
- Is the problem in application code, data shape, infrastructure, process, or all four?

This changes the conversation from “Should we rewrite?” to “What evidence would justify the next change?”

## Five areas worth checking

### 1. The delivery path

Look at how a feature moves from idea to production.

Warning signs include:

- Nobody can explain the deployment path end to end.
- Tests are slow, unreliable, or routinely skipped.
- A change requires several unrelated systems to be edited together.
- Rollback is theoretically possible but not practised.

A modernization plan should improve the team’s ability to make safe changes, not only replace old code with new code.

### 2. The request and data path

Trace one slow or important user workflow through the system:

```text
browser or mobile client
        ↓
controller / API endpoint
        ↓
application services and authorization
        ↓
database queries and external services
        ↓
background work, notifications, or reporting
```

The goal is not to collect every possible metric. It is to find where the workflow spends time, where failures disappear, and where ownership becomes unclear.

### 3. Background jobs and exports

Reports, imports, notifications, and large exports often expose platform weaknesses first. A synchronous request may appear simple, but it creates a poor failure boundary when the work is large or unpredictable.

A healthier pattern is usually:

1. Accept the request.
2. Enqueue a job.
3. Track progress and failure state.
4. Store the generated result safely.
5. Notify the user when it is ready.
6. Provide a controlled download path.

The exact implementation depends on the platform, but the architectural question is general: does the user-facing request have to remain open while the system performs work that belongs in an asynchronous workflow?

### 4. Operational evidence

When a system is slow or unreliable, the team needs enough evidence to make the next decision.

Useful evidence may include:

- Request duration by endpoint or workflow
- Database query timing and query volume
- Job duration, retries, and failure reasons
- Error rates and affected users
- Deployment frequency and rollback history
- Resource saturation during the problem window

A dashboard is not automatically observability. Evidence is useful when it helps somebody choose an action.

### 5. Boundaries between product and platform

Learning platforms often combine course content, assessment, reporting, users, integrations, billing, and administration. Over time, these concerns can become tightly coupled.

That does not mean every concern should immediately become a separate service. It does mean the team should identify which boundaries are causing real delivery or operational pain.

A good first boundary may be a reporting workflow, an integration, or a clearly owned domain module—not a wholesale migration to microservices.

## Modernization should reduce uncertainty

A useful modernization plan answers four questions:

1. **What is hurting the business or users now?**
2. **What evidence supports that conclusion?**
3. **What is the smallest change that could improve it?**
4. **How will we verify whether the change worked?**

If a proposal cannot answer the fourth question, it is not yet a reliable plan.

The answer may be a code change, a database improvement, better job instrumentation, a deployment safety measure, a clearer ownership boundary, or a decision not to change something yet.

## A practical first audit

For a small team, a first review can be deliberately narrow:

- Choose one painful workflow.
- Review the relevant code and data path.
- Inspect the current tests and deployment path.
- Gather the available performance and error evidence.
- Interview the people who operate or support the workflow.
- Produce a prioritized list of findings.
- Recommend one or two changes that can be verified.

This is more useful than producing a generic architecture diagram disconnected from the team’s actual constraints.

## What I would avoid

I would be cautious about:

- Recommending a rewrite before measuring the current problem
- Introducing microservices to solve unclear ownership
- Adding AI where conventional automation would be simpler
- Treating a framework upgrade as a complete modernization strategy
- Building a dashboard without a decision it is meant to support
- Promising a precise outcome before understanding the system

The goal is not to defend legacy software. The goal is to make the next decision safer and more valuable.

## A small next step

If a Rails or LMS platform is becoming slow, fragile, or difficult to extend, start by writing down one workflow that is causing measurable pain. Record who is affected, how often it happens, what the current workaround is, and what evidence you already have.

That short exercise often reveals whether the next step should be a focused technical investigation, a product decision, an operational improvement, or no major change at all.

I am developing a fixed-scope [Rails/LMS Reliability and Modernization Audit](/consulting/) for teams that need this kind of evidence-led first review. The aim is to understand the system and produce a practical roadmap—not to sell a rewrite before the problem is understood.
