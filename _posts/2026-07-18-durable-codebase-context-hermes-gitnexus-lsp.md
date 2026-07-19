---
layout: post
title: "Giving Hermes Durable Codebase Context with GitNexus, LSP, and AGENTS.md"
date: 2026-07-18 19:14:29 +0100
author: "Joey Wang"
description: "How I gave Hermes a persistent local code graph, semantic diagnostics, and stable project instructions without turning agent memory into a stale symbol index."
tags: [hermes-agent, gitnexus, mcp, lsp, code-intelligence]
categories: [AI Engineering]
---

# Giving Hermes durable codebase context with GitNexus, LSP, and AGENTS.md

Every coding agent eventually develops the same bad habit: repeated grep.

I ask where a request enters the system. It searches for the route name.

I ask what calls a service. It searches for the class name.

I ask what might break if we change a method. It searches for references, opens a few files, loses part of the chain when the context window fills, then performs roughly the same search again five minutes later.

This works on a small repository. On a large one, it wastes time and tokens while producing an incomplete model of the code.

The problem is not that grep is bad. I use it constantly. The problem is asking grep to provide architecture.

I wanted Hermes to keep three different kinds of codebase knowledge:

1. A graph of symbols, relationships, and execution paths.
2. Compiler-aware feedback after Hermes changes code.
3. Stable project instructions that survive between sessions.

Those jobs belong to GitNexus, Hermes's native LSP diagnostics, and `AGENTS.md` respectively.

They overlap a little, but they are not interchangeable.

## Why repeated grep is wasteful

Text search answers a narrow question:

> Which files contain this string?

Most codebase questions are wider than that:

- Which controller eventually reaches this database query?
- Which implementations sit behind this interface?
- What depends on this symbol?
- Which tests cover the affected path?
- Where does data change shape between the API and persistence layer?
- What is the likely blast radius of this refactor?

A sequence of grep calls can approximate those answers. The agent searches for a symbol, reads each result, searches for the next symbol, then reconstructs the chain in its working context.

That reconstruction is temporary. Once the session is compressed or restarted, much of it disappears.

It is also easy to miss relationships that are not represented by the exact text being searched. Aliases, re-exports, interface implementations, dependency injection, and indirect calls all make plain text search less useful.

I still want Hermes to use grep for exact strings, config values, log messages, and quick local checks. I just do not want every architecture question to begin with repository archaeology.

## Three layers, three jobs

The setup makes more sense if each component has a narrow responsibility.

```text
AGENTS.md
  Stable architecture, commands, conventions, and constraints
                         |
                         v
Hermes session ---> GitNexus graph ---> symbols, paths, dependencies, impact
       |
       +--------> edits files
                         |
                         v
                Hermes native LSP
                post-write semantic diagnostics
```

### GitNexus: the structural graph

GitNexus indexes the repository into `.gitnexus` and exposes code relationships through MCP.

Its tools include:

- `list_repos`
- `query`
- `context`
- `impact`
- `trace`
- `detect_changes`
- `route_map`

This is the layer I use for questions about structure.

A graph query can give Hermes a focused slice of the repository instead of forcing it to rediscover the same call chain through repeated searches. `impact` is useful before changing a symbol. `trace` helps follow execution. `route_map` provides a higher-level view of routes through the code. `context` gathers relevant code around a symbol or result.

The graph is derived state. It needs to match the current checkout.

### Hermes LSP: feedback on edits

Hermes's native LSP support currently provides semantic diagnostics after a write.

That means Hermes can edit a file and receive language-aware errors such as unresolved names, invalid types, or broken imports. This is much better than relying on syntax alone.

It does not currently give the model general-purpose navigation such as "find all references", "go to definition", or "show implementations" as callable tools.

That distinction matters. I would not describe native LSP as a replacement for GitNexus. In this workflow:

- GitNexus helps Hermes understand before it edits.
- LSP diagnostics catch semantic mistakes after it edits.

The test suite still has the final word.

Before relying on that second layer, I check which language servers are actually installed:

```bash
hermes lsp status
hermes lsp list
```

Hermes supports Pyright, TypeScript Language Server, `gopls`, Rust Analyzer, `clangd`, and several others. I install only what the repository needs:

```bash
hermes lsp install pyright
hermes lsp install typescript
```

The servers start lazily when Hermes edits a matching file inside a Git repository. A configured LSP with a missing server binary is still just syntax checking, so `hermes lsp status` belongs in the setup verification.

### `AGENTS.md`: stable project memory

`AGENTS.md` holds facts that should remain useful even when implementation details move around:

- the repository's purpose
- major subsystems
- architectural boundaries
- build and test commands
- package management rules
- generated directories
- security constraints
- files that must not be edited
- expectations for verification

Hermes reads `AGENTS.md` from its current working directory. I start Hermes at the repository root so the intended file is loaded.

A small example:

```markdown
# Project instructions

## Architecture

- `src/api/` owns HTTP request parsing and response formatting.
- `src/domain/` contains business rules and must not import `src/api/`.
- `src/storage/` owns database access.
- Background jobs enter through `src/workers/`.

## Commands

- Install dependencies with `uv sync`.
- Run unit tests with `uv run pytest tests/unit`.
- Run the full check with `make verify`.

## Change rules

- Do not edit generated files under `src/generated/`.
- Database schema changes require a migration.
- Check callers before changing public service interfaces.
- Run the narrowest relevant tests, then `make verify`.
```

This file should explain the system, not duplicate it.

I would not put a live list of every class, route, or caller in `AGENTS.md`. Those facts go stale quickly and belong in the graph.

## Why ordinary Hermes memory is not a symbol index

Hermes memory is useful for durable information about how I work:

- I prefer `uv` over direct `pip` installs.
- A repository requires a particular verification command.
- A recurring deployment task follows a known procedure.
- A previous debugging session exposed a reusable pitfall.

It is a poor place to store fast-changing symbol maps.

A memory such as "method A is called by services B and C" becomes wrong as soon as somebody changes the branch. Worse, the stale statement still sounds authoritative in a later session.

I use this rule:

| Information | Where it belongs |
|---|---|
| Symbol relationships and call paths | GitNexus |
| Semantic errors caused by an edit | Hermes LSP diagnostics |
| Stable architecture and repository rules | `AGENTS.md` |
| Personal preferences and reusable procedures | Hermes memory |
| Exact current text | Repository search and file reads |

Memory should reduce repeated human explanation. It should not become a second, stale code index.

## The first installation failed

The first useful lesson arrived before the graph did.

I tried the obvious command on a machine running Node 24:

```bash
npm install --global gitnexus
```

The install reached GitNexus's native Tree-sitter dependencies and failed inside `node-gyp`. The important lines were not the final `make` error. They were the versions around it:

```text
node v24.18.0
tree-sitter 0.21.1
V8 template and external pointer compilation errors
```

This was not a missing C++ compiler. The native Tree-sitter binding used by the package did not build against the Node 24/V8 headers on that host.

GitNexus 1.6.9 declares `node >=22.0.0`, so Node 24 satisfies the package's advertised engine range. The problem was narrower: its pinned `tree-sitter 0.21.1` native addon did not build against Node 24's V8 headers on this ARM64 host.

Node 22 was therefore a compatibility workaround for this package version, not a reason to downgrade the machine. I manage runtimes with `mise`, so I kept Node 24 as the default and installed GitNexus in its own prefix under Node 22:

```bash
mise install node@22.23.1

mkdir -p "$HOME/.local/share/gitnexus-cli"

mise x node@22.23.1 -- npm install \
  --prefix "$HOME/.local/share/gitnexus-cli" \
  gitnexus@1.6.9
```

Then I added a small wrapper at `$HOME/.local/bin/gitnexus`:

```bash
#!/usr/bin/env bash
set -euo pipefail

exec mise x node@22.23.1 -- \
  "$HOME/.local/share/gitnexus-cli/node_modules/.bin/gitnexus" "$@"
```

After making it executable, I checked the actual runtime rather than assuming the package was healthy:

```bash
chmod 0755 "$HOME/.local/bin/gitnexus"
gitnexus --version
gitnexus doctor
```

`gitnexus doctor` confirmed that GitNexus was running on Node 22, the native LadybugDB module loaded, and the graph store was available.

The useful debugging rule here is simple: when a Node install fails deep inside native code, record the Node, npm, package, and native dependency versions before trying random compiler flags. A supported LTS runtime is often a better fix than forcing an old native addon through a new V8 API.

## Building the GitNexus index

From the project root:

```bash
cd /path/to/project
gitnexus analyze --index-only
```

GitNexus writes its index under:

```text
/path/to/project/.gitnexus
```

I use `--index-only` because I maintain `AGENTS.md` myself and do not want the indexing step to install editor-specific skills or rewrite context files. Architecture instructions deserve review like any other documentation. I do not want an indexing command silently replacing them with generated text.

The index is local derived data, but derived does not mean harmless. It can contain enough structural information to expose private implementation details. I treat `.gitnexus` as sensitive and avoid committing it unless the project has made a deliberate decision to version it.

For a private repository, I would normally add it to the repository's ignore rules:

```gitignore
.gitnexus/
```

Before doing that, I check whether the project already has a policy for generated indexes.

## Connecting GitNexus to Hermes

GitNexus exposes its MCP server over stdio:

```bash
gitnexus mcp
```

Hermes can register the server with:

```bash
hermes mcp add gitnexus \
  --command /home/your-user/.local/bin/gitnexus \
  --connect-timeout 120 \
  --args mcp
```

The command tells Hermes to launch GitNexus as a local subprocess and communicate over stdin and stdout. It does not require a public endpoint.

After adding it, I inspect and test the configured server:

```bash
hermes mcp list
hermes mcp test gitnexus
```

MCP servers and their tools are discovered when Hermes starts. I restart Hermes, or reload MCP configuration where supported, before expecting the new tools in a session.

The discovered tool names are prefixed by the server name. A GitNexus tool such as `impact` will normally appear to Hermes in a form like:

```text
mcp_gitnexus_impact
```

## Expose only the tools Hermes needs

MCP is an execution boundary. I do not expose every tool from every server by default.

Hermes provides an interactive tool selector:

```bash
hermes mcp configure gitnexus
```

For codebase understanding, I enable only the GitNexus query and analysis tools I intend Hermes to use:

```text
list_repos
query
context
impact
trace
detect_changes
route_map
```

These form a read-only analysis surface for this workflow. They let Hermes inspect the index without giving the MCP server a general-purpose repository write path.

This improves more than security. A smaller tool list gives the model fewer overlapping choices and makes its behaviour easier to review.

I keep terminal and file writes under Hermes's normal approval and verification flow. GitNexus answers structural questions; it does not need to become the component that edits the repository.

## Index freshness is part of correctness

A code graph is useful only when it describes the checkout Hermes is editing.

The `.gitnexus` directory is not durable truth. It is a cache derived from a particular repository state.

I assume the index may be stale after:

- switching branches
- pulling or rebasing
- changing a large set of files
- generating code
- applying a migration that changes model relationships
- moving or renaming symbols
- returning to the repository after other developers have worked on it

GitNexus exposes `detect_changes`, which gives Hermes a way to compare the index with the working tree. I use it near the start of a task and again before trusting impact analysis after substantial edits.

If the detected changes affect the area under investigation, I rebuild the index:

```bash
cd /path/to/project
gitnexus analyze --index-only
```

For a small patch, it can be reasonable to query the existing graph, read the changed files directly, and rely on tests for the final check. For a branch switch or broad refactor, rebuilding is cheaper than reasoning from stale relationships.

I also make the freshness expectation explicit in `AGENTS.md`:

```markdown
## Code graph

- GitNexus data lives in `.gitnexus/`.
- Run `detect_changes` before relying on graph results.
- Re-run `gitnexus analyze --index-only` after branch changes or broad refactors.
- Treat graph results as derived context. Confirm critical paths against current source.
```

That last line is deliberate. An index is an aid, not proof.

## A practical Hermes workflow

My workflow now has four phases.

## 1. Load the stable context

I start Hermes from the repository root:

```bash
cd /path/to/project
hermes
```

Hermes loads the root `AGENTS.md`, which tells it how the repository is organised and how changes must be verified.

My first prompt names the subsystem and asks Hermes to check graph freshness before investigating:

```text
Investigate how requests reach the billing service.

Read the project instructions first. Use GitNexus detect_changes before
trusting the index. Do not edit anything yet. Return the entry point,
main call path, state transitions, and relevant tests.
```

This is much more precise than "look around the repo".

## 2. Query before reading broadly

Hermes can begin with `query` or `route_map`, then narrow the result with `context` and `trace`.

The intended sequence is roughly:

```text
route_map or query
        |
        v
identify likely entry point
        |
        v
trace execution path
        |
        v
context for relevant symbols
        |
        v
read exact source files
```

The graph reduces the search space. It does not remove the need to read source.

Once GitNexus identifies the important symbols and files, Hermes opens those files with its normal file tools. This confirms names, conditions, comments, and implementation details against the current checkout.

Plain search still appears when useful. If the task involves a literal error message or configuration key, grep may be the shortest path.

## 3. Check impact before editing

Before changing a public function, interface, route, or data model, I ask Hermes to run `impact`.

A refactor prompt might look like this:

```text
Use GitNexus impact analysis on PaymentService.authorize.

List direct callers, indirect dependants, tests, and API boundaries that
may be affected. Confirm the important results in the current source.
Then propose the smallest change. Do not edit until the impact report is
complete.
```

This creates a useful pause between understanding and modification.

It also gives me something concrete to review. If the impact report includes an unexpected worker or migration path, I can change the plan before Hermes touches the code.

## 4. Let LSP and tests challenge the edit

After Hermes writes a file, native LSP diagnostics provide immediate semantic feedback.

I expect Hermes to resolve those diagnostics before running tests. Then it runs the narrowest relevant test set, followed by the repository's required broader check from `AGENTS.md`.

The sequence is:

```text
edit
  |
  v
post-write LSP diagnostics
  |
  v
fix semantic errors
  |
  v
targeted tests
  |
  v
project verification command
  |
  v
review diff and graph freshness
```

For a structural refactor, I ask for another `detect_changes` check and, when useful, a fresh analysis before the final impact review. The post-change graph can reveal callers that no longer resolve as expected, but compilation and tests remain the authority.

## Private repositories need a tighter boundary

A private repository changes the risk calculation.

The source may stay on the same machine, but the index still contains private structural data. Tool results sent to the model can also include symbol names, paths, comments, and code excerpts.

I apply a few rules.

First, I use the local stdio transport:

```bash
hermes mcp add gitnexus \
  --command /home/your-user/.local/bin/gitnexus \
  --connect-timeout 120 \
  --args mcp
```

There is no reason to publish the MCP server to the internet for a single-machine workflow.

Second, I pin the GitNexus package version in the isolated installation. The MCP configuration launches that reviewed local wrapper instead of downloading the latest package on every startup. The approved version belongs in the project's setup documentation or dependency policy.

Third, I expose only the read-only analysis tools and disable anything I do not need:

```bash
hermes mcp configure gitnexus
```

Fourth, I keep `.gitnexus/` out of commits, backups, and shared build artifacts unless those systems are approved to hold source-derived data.

Finally, I check the model provider policy. Local MCP transport keeps the server local; it does not mean every result remains local. Hermes may send selected tool output to the configured model. For sensitive code, the model endpoint, retention policy, logging configuration, and account controls all matter.

Local indexing narrows the exposure. It does not erase it.

## What goes into `AGENTS.md`

The most useful `AGENTS.md` is short enough to trust.

I include:

- a map of major directories
- dependency direction between layers
- entry points that are stable
- build, lint, and test commands
- generated or protected files
- rules for migrations and public interfaces
- the GitNexus freshness policy
- security constraints relevant to agents

I leave out:

- complete symbol inventories
- current caller lists
- temporary branch details
- copied implementation code
- guesses about undocumented behaviour
- incident conclusions that have not been verified

If a fact can change during an ordinary refactor, GitNexus or the source should answer it.

If a fact describes how the project should be changed, `AGENTS.md` should answer it.

## The resulting division of labour

The final setup is intentionally boring:

```text
Need current architecture?
    Ask GitNexus.

Need exact implementation?
    Read the source.

Need post-edit semantic feedback?
    Read Hermes LSP diagnostics.

Need project rules next week?
    Put them in AGENTS.md.

Need a reusable personal preference or procedure?
    Use Hermes memory.

Need proof that the change works?
    Run the tests.
```

This does not eliminate grep. It stops grep from carrying responsibilities it was never designed to carry.

The useful change is not that Hermes suddenly "knows the whole codebase". It does not. The graph can be stale, `AGENTS.md` can be wrong, diagnostics can miss runtime behaviour, and memory can outlive the fact it describes.

The improvement is that each kind of knowledge now has an owner.

Hermes can query structure instead of rebuilding it from text search, check edits with language-aware diagnostics, and reload stable project constraints at the start of the next session. When the repository changes, I refresh the derived layer rather than teaching the agent a new set of soon-to-be-stale facts.

That is enough to make repeated codebase work noticeably less repetitive, while keeping the final answer where it belongs: in the current source and the test results.
