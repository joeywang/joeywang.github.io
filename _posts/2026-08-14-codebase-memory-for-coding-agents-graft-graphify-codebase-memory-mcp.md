---
layout: post
title: "Codebase Memory for Coding Agents: Graft, Graphify, and codebase-memory-mcp"
date: 2026-08-14 18:00:00 +0000
author: "Joey Wang"
description: "A practical comparison of Graft, Graphify, and codebase-memory-mcp: what each indexes, how each feeds coding agents, and when to use one instead of another."
tags: [ai, coding-agents, code-intelligence, code-graph, context-engineering, mcp, developer-tools]
categories: [AI, Engineering]
---

# Codebase memory for coding agents: Graft, Graphify, and codebase-memory-mcp

A coding agent has a bad habit.

Give it the same repository tomorrow and it starts over: grep for a class, read a controller, follow an import, search for a test, discover a second implementation, then ask where the real business logic lives.

The agent may be capable of doing this work. The problem is that it keeps paying for the same exploration.

That is why a new class of tools is interesting. They build a durable view of a codebase before the agent needs it. The names are easy to mix up, though. Graft, Graphify, and codebase-memory-mcp all talk about graphs, code intelligence, and fewer tokens. They are not the same product wearing different logos.

My short version is:

- [Graft](https://github.com/NanoNets/Graft) gives an agent a readable architectural guide.
- [Graphify](https://github.com/Graphify-Labs/graphify) builds a queryable graph across code and project material.
- [codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) exposes a high-performance structural code database through MCP.

They overlap. Their centre of gravity is different.

## The recurring problem

A normal coding-agent session often looks like this:

```text
user request
  -> search the repository
  -> open likely files
  -> follow symbols and imports
  -> form a provisional architecture
  -> make a change
  -> discover one more hidden dependency
  -> revise the plan
```

Some exploration is necessary. A stale or incorrect map is worse than no map. But repeating the same exploration for every task wastes tokens and makes the agent's first guess depend on whatever files it happened to open first.

The useful question is not "Can a tool index the repository?" Almost all of them can.

The useful questions are:

- What does the tool treat as a fact?
- What does it infer with a model?
- Does it produce a document, a database, or an API?
- How does it stay fresh after a code change?
- Can an agent use it without being overwhelmed by another tool surface?
- What happens when the index is wrong?

## Three different meanings of codebase memory

The word "memory" hides three different designs.

### Graft: memory as an architectural briefing

Graft builds a tree-sitter-based structural graph and turns parts of it into linked Markdown explanations. The intended reader is the coding agent. Instead of asking the agent to rediscover the repository, Graft gives it a set of pages describing subsystems, concepts, important files, and relationships.

That makes Graft feel less like a database and more like an architectural briefing:

```text
graft/
  auth.md
  persistence.md
  api-layer.md
  domain-model.md
```

The Markdown is useful because language models are good at reading a compact explanation with links back to source files. Graft also provides hooks and MCP integration for tools such as Claude Code, Cursor, Codex, and Gemini.

There is a trade-off. The structural layer can be deterministic, but the summaries and conceptual grouping are a different kind of output. They may be useful, but they are not compiler facts. A generated statement such as "BillingService owns subscription renewal" should still be checked against the code.

Graft's README reports impressive project benchmarks, including lower token use, fewer tool calls, lower wall-clock time, and a SWE-bench Verified result of 66% compared with 54% for the cold baseline in its reported test. Those are project-reported results. They are evidence worth testing, not a guarantee for every Rails or Node repository.

Use Graft when the main problem is:

> The agent can query the files, but it does not form a useful architecture model quickly enough.

### Graphify: memory as a general knowledge graph

[Graphify](https://github.com/Graphify-Labs/graphify) has a wider scope. It can connect code with Markdown, SQL schemas, configuration, PDFs, images, and other project material. Its code path uses tree-sitter parsing and presents a graph that can be queried or rendered as an HTML visualization.

Graphify is especially interesting when the system is bigger than the source tree. A route may be defined in code, described in an API document, constrained by a SQL schema, and explained in an architecture decision record. A code-only index misses some of that context.

Graphify also makes a useful distinction between edges extracted directly from source and edges inferred by the tool. That distinction matters. A graph that says "these two concepts are related" is not the same as a graph that proves "function A calls function B."

The experience is closer to:

```text
code + docs + schemas + project material
  -> knowledge graph
  -> query / path / explain
  -> HTML view or agent context
```

Use Graphify when the main problem is:

> The architecture is spread across code, documents, schemas, and diagrams, and I need to inspect them together.

The wider scope also creates wider privacy and accuracy questions. Code parsing can remain local, but semantic processing for documents or media may use a configured model. The graph is not automatically safe just because the command runs on your laptop.

### codebase-memory-mcp: memory as a structural code database

[codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp) takes the most infrastructure-like approach of the three. It builds a persistent local graph and exposes structural queries through MCP. The project describes tree-sitter support across many languages, deeper semantic resolution for selected languages, SQLite-backed storage, incremental indexing, and a native binary with a background service.

This is the kind of system I would use for questions like:

```text
Who calls this method?
Which routes reach this service?
What will this diff affect?
Which functions have no callers?
Where does this cross-service request originate?
```

Those questions benefit from exact edges, symbol identity, type information, and graph traversal. They should not depend only on a friendly paragraph generated by a model.

The result is less like a book and more like a local code database with an MCP API. That makes it a strong candidate for an agent that needs repeatable structural lookups, especially on large repositories.

It also means more moving parts: a native binary, persistent database, watcher or daemon, MCP tools, language-specific behavior, and an index lifecycle to understand. A claim of support for 158 languages does not mean every language has the same call-graph or type-resolution quality. The language and framework in the repository still matter.

Use codebase-memory-mcp when the main problem is:

> The agent needs fast, repeatable answers about symbols, calls, routes, and change impact.

## The comparison

| Dimension | Graft | Graphify | codebase-memory-mcp |
| --- | --- | --- | --- |
| Main output | Linked Markdown context | JSON graph, HTML view, reports | Persistent graph queried through MCP |
| Primary user | Coding agent | Developer and agent | Coding agent and developer tools |
| Main strength | Architectural explanation | Code plus docs and schemas | Structural queries and impact analysis |
| Code facts | tree-sitter plus generated explanations | tree-sitter AST and labeled edges | tree-sitter, LSP-style resolution, graph indexes |
| LLM dependence | More visible in summaries and grouping | Optional for non-code semantic layers | Lower for structural queries; model interprets results |
| Integration style | Hooks, MCP, agent-specific workflow | CLI, skill, optional MCP/graph backends | MCP server, local database, watcher/daemon |
| Best question | "How does this subsystem fit together?" | "How are these code and project artifacts connected?" | "What calls or depends on this symbol?" |
| Main risk | Plausible but wrong summaries | Broad graph with mixed evidence types | Operational complexity and uneven language depth |

The boundary is not absolute. Graft can expose queries. Graphify can serve agents. codebase-memory-mcp can support higher-level explanations. The table is about the default shape of each project, not a hard technical limitation.

## What should be treated as fact?

This is the part I would not skip.

A useful code-intelligence system should separate at least three layers:

```text
source-proven facts
  -> AST, symbols, imports, calls, routes

inferred relationships
  -> likely subsystem, related concepts, probable data flow

human or model explanations
  -> readable summaries and suggested architecture
```

The further down that list we go, the more useful the prose may become and the more carefully it needs to be checked.

This is also why I would not let a generated Markdown page become the only source of truth. The source code remains authoritative. The graph is an index. The explanation is a convenience layer.

## When I would use each one

### Use Graft for an agent-facing first pass

I would try Graft when:

- the repository is large enough that every session starts with the same orientation work;
- the main cost is the agent reading too many files before it understands the system;
- readable subsystem summaries would help more than another large query API;
- the team is willing to review generated context and keep it fresh;
- the integration with the chosen coding agent is more important than broad language coverage.

I would not start by committing generated context to every repository. First check what it writes, what it sends to a model provider, how updates are detected, and whether a stale page is obvious to the agent.

### Use Graphify for cross-artifact architecture

I would try Graphify when:

- the real architecture lives in code and documentation together;
- SQL schema, configuration, ADRs, and API material are part of the debugging path;
- a human needs to browse the result visually;
- distinguishing extracted edges from inferred edges is important;
- the project needs a knowledge map rather than only a call graph.

This is a good fit for system design work, but it may be too broad for a small repository where a symbol graph is enough.

### Use codebase-memory-mcp for structural code intelligence

I would try codebase-memory-mcp when:

- callers, callees, routes, and blast radius are frequent questions;
- the repository is large or split across services;
- incremental indexing matters;
- several MCP-capable agents should share the same local code index;
- the team wants a query backend rather than generated prose as the primary artifact.

I would first test the actual languages and frameworks in the repository. "Supports the language" is only the start. The important question is whether it resolves the relationships your application uses.

## What about GitNexus and QMD?

For my own setup, these tools would not replace everything that already exists.

I think about the layers like this:

```text
GitNexus
  -> symbols, execution flows, impact paths

codebase-memory-mcp
  -> alternative structural code graph and MCP query backend

Graft
  -> agent-facing architecture summaries

Graphify
  -> code + docs + schemas + broader project graph

QMD
  -> durable Markdown knowledge and retrieval

AGENTS.md / skills
  -> stable instructions and repeatable workflows
```

The danger is building three indexes that all claim to explain the same repository and then allowing them to disagree silently.

A sensible architecture has one preferred source for each question. For example:

- use a structural graph for caller and impact questions;
- use QMD for durable design notes and decisions;
- use a generated summary only as a navigation aid;
- use the source code and tests to settle disagreements;
- keep approval boundaries outside the model-generated context.

Code intelligence should reduce rediscovery, not create a second kind of rediscovery where the agent searches three competing memories before it opens the source.

## A small evaluation beats a benchmark headline

Before installing any of these on a private work repository, I would use a disposable fixture and six tasks:

1. Find the complete call path for a route.
2. Identify the blast radius of a shared interface change.
3. Explain a cross-file business workflow.
4. Locate the tests that should change with a feature.
5. Review a small diff for affected components.
6. Implement a small, well-specified fix.

For each tool, record:

- correctness;
- missed dependencies;
- misleading explanations;
- token count;
- tool calls;
- latency;
- index refresh time;
- stale results after a code change;
- CPU and disk usage;
- what leaves the machine;
- how cleanly the integration can be removed.

The last two matter as much as the first two. A local index can still leak information if summaries are sent to an external provider. A fast graph that is hard to refresh is not a durable memory system. A lower token count is not useful if the agent makes a wrong change with more confidence.

## My current recommendation

If I had to evaluate them in order, I would start with codebase-memory-mcp for structural queries, then Graft for agent-facing explanations. I would bring in Graphify when the test repository includes important schemas, ADRs, configuration, and other documents that do not fit naturally into a code-only graph.

That is not a ranking of project quality. It is a division of jobs.

The design rule I keep coming back to is simple:

> Use a graph to answer what the code proves. Use generated context to help the agent find its way. Use durable notes for decisions that humans have actually reviewed.

The best codebase memory is not the one with the most nodes. It is the one that reduces repeated exploration without making the agent forget how to check the source.

## Sources

- [NanoNets/Graft](https://github.com/NanoNets/Graft)
- [Graphify-Labs/graphify](https://github.com/Graphify-Labs/graphify)
- [DeusData/codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp)
- [Graft README and benchmark notes](https://github.com/NanoNets/Graft/blob/main/README.md)
- [codebase-memory-mcp documentation](https://deusdata.github.io/codebase-memory-mcp/)
