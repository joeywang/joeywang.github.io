---
layout: post
title: "Graph Engineering: Connecting Code, Agents, and Evidence Without Building a New Graph Database"
description: "How to use code graphs, Markdown knowledge, workflow manifests, and live verification to make complex engineering systems easier to change safely."
date: 2026-08-17 18:00:00 +0100
author: "Joey Wang"
tags: [software-architecture, ai-agents, graph-engineering, developer-tools, knowledge-management]
categories: [Engineering]
---

Most engineering systems do not suffer from a lack of information. They suffer from disconnected information.

A code symbol is connected to callers, tests, API contracts, deployments, and operational risk. A research note is connected to an experiment, a measured result, and perhaps a future consulting service. An agent task is connected to tool calls, artifacts, verification, and decisions.

Those relationships often exist only in somebody's head.

I have been calling the practice of making these relationships explicit **graph engineering**. It does not necessarily mean introducing Neo4j, a universal ontology, or another database. It means designing workflows around entities, edges, provenance, and transitions while keeping the existing systems of record intact.

## The problem with isolated tools

A modern engineering workflow may contain all of these systems:

- a Rails or Node application;
- several client and service repositories;
- GitHub pull requests and CI;
- code-intelligence indexes;
- agent skills and long-running jobs;
- personal and project knowledge bases;
- benchmark notes and research links;
- production deployment and observability systems.

Each system can work well in isolation. The expensive failures happen at the boundaries.

A shared contract changes, but nobody knows which client consumes it. A test passes, but the browser flow is broken. A useful research idea is saved, but never becomes an experiment. An autonomous agent reports success, but the evidence is not connected to the claim.

The missing abstraction is often not another document. It is a relationship.

## A layered graph architecture

My current approach is to keep each tool focused:

```text
Git-backed Markdown       decisions, workflows, research, evidence
IWE / durable memory      compact relational knowledge and corrections
QMD                       semantic retrieval over long-form documents
GitNexus                  code symbols, callers, routes, and execution flows
Live tools                tests, CI, deployments, and current system state
```

These layers are connected, but they do not have the same authority.

A code graph is useful for discovering callers. It does not replace the checked-out source code. A QMD result is useful for finding a design note. It does not replace a live production check. A workflow manifest can reveal an expected dependency. It does not prove that the current implementation still matches it.

That distinction is essential. Graphs are excellent reasoning and discovery structures; they are not automatically sources of truth.

## Graph one: product contracts across repositories

Consider a learning activity launched from one application into an external provider. The useful graph is not just a list of endpoints:

```text
Learner -> Program -> Activity -> ExternalActivitySession
ExternalActivitySession -> Provider
ExternalActivitySession -> LaunchDescriptor
LaunchDescriptor -> launch_url / target_origin
Provider callback -> Completion Event
Completion Event -> learner history / reporting
```

In a multi-repository product, these nodes may be owned by different teams or codebases. A small change to `target_origin` can affect server authorization, a client iframe, browser `postMessage` handling, mobile WebView behavior, and security tests.

A compact contract manifest can make that visible:

```yaml
entities:
  - id: external_activity_session
    owner: session-service
    consumers: [application, client, web-host]
  - id: launch_url
    owner: session-service
    consumers: [client, web-host]
  - id: target_origin
    owner: session-service
    consumers: [client, web-host]
    security_boundary: postMessage destination validation

change_triggers:
  - fields: [target_origin, launch_url]
    requires: [security_review, client_tests, browser_verification]
```

This is not an API schema and should not pretend to be one. It is an impact-planning sidecar. Before relying on it, I still inspect the live repositories, query the code graph, run focused tests, and verify the browser behavior.

The desired output is an **impact packet**:

```text
changed contract
  -> affected server route
  -> affected client launcher
  -> security boundary
  -> focused tests
  -> browser/mobile checks
  -> deployment risk
```

That is more useful than a generic architecture diagram because it answers what a real change requires.

## Graph two: code to tests to deployment

Code-intelligence tools already provide much of the code graph:

```text
changed symbol -> caller -> execution flow -> route/component
               -> contract -> affected test -> service -> deployment
```

The next step is to connect the derived code relationships to deterministic checks. A pull request should not only say which files changed. It should help answer:

- Which execution flows include the changed symbol?
- Which contracts cross repository boundaries?
- Which focused tests should run?
- Does the change need browser or mobile evidence?
- Does the change touch a production approval boundary?

This is particularly valuable for agent-assisted development. An agent can use the graph to narrow investigation, but it must still verify the result with tests, diffs, and live checks.

## Graph three: agent execution and evidence

Long-running agents also benefit from graph-shaped state:

```text
Task -> decision -> tool call -> result -> artifact -> verification -> next decision
```

Each node should retain its epistemic status:

- **observed:** returned by a tool;
- **inferred:** reasoned by the model;
- **proposed:** not executed;
- **approved:** explicitly authorized;
- **verified:** supported by a test, readback, or live check.

This prevents a subtle but dangerous failure: an agent's explanation becomes indistinguishable from evidence.

It also supports safe restarts. A long task can preserve a structured handoff:

```text
objective
current status
evidence collected
artifacts changed
remaining risks
next action
```

A fresh context can then continue from the workspace and handoff rather than carrying every previous conversational detail. The durable graph is the important state, not the entire transcript.

## Graph four: from research link to consulting evidence

I also want my AI-resource backlog to become more than a collection of interesting links. Each resource should be connected to a concept, an existing capability, an experiment, and an evidence artifact:

```text
resource -> concept -> existing capability -> experiment
         -> measured result -> article -> consulting evidence
```

For example, a GPU roofline explanation is interesting by itself. It becomes professionally useful when connected to:

```text
roofline model
  -> local inference benchmark
  -> prefill/decode measurements
  -> reproducible report
  -> technical article
  -> evidence for inference-engineering consulting
```

The same pattern applies to agent harnesses, memory systems, reinforcement learning courses, and automated media pipelines. The question changes from:

> “What links did I save?”

To:

> “Which saved idea can produce a verified experiment or decision?”

That is a much better learning loop.

## What I am implementing first

I am deliberately starting with small, versioned artifacts:

1. A graph-engineering architecture note describing the boundaries between memory, documents, code intelligence, and live systems.
2. A LearningFlow contract manifest connecting entities, owners, consumers, security boundaries, and verification edges.
3. A pilot workflow describing how to compare the manifest with real code-graph results and focused tests.
4. A decision record stating that no central graph database is needed during the pilot.
5. A blog and research workflow that links saved resources to experiments and evidence rather than only tags.

The first success criterion is simple:

> Can this graph help answer what is affected when a shared contract changes?

If the answer is no, adding more nodes or adopting a more sophisticated graph database will not help.

## What I am not doing

I am not importing every repository into a universal ontology. I am not treating a vector index as executable truth. I am not allowing an unattended graph process to rewrite skills, production configuration, or memory. I am not putting credentials or customer data into relationship manifests.

The graph should make decisions safer, not make the system more magical.

## A practical starting point

For a team considering this approach, choose one painful boundary:

- a cross-service API;
- a browser or mobile integration;
- a frequently failing deployment path;
- a long-running agent task;
- or a research-to-content workflow.

List the entities. Add only the relationships needed to answer a real question. Record where each relationship came from. Connect the graph to one deterministic verification step. Then compare the predicted impact with what actually happened.

That small feedback loop is more valuable than a large architecture project.

Graph engineering is not about turning everything into nodes and edges. It is about making the important edges impossible to forget.
