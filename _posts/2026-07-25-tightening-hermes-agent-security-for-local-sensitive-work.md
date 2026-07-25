---
layout: post
title: "Tightening Hermes Agent Security for Local Sensitive Work"
date: 2026-07-25 14:27:42 +0100
author: "Joey Wang"
description: "How I tightened my Hermes Agent setup after adding a local model path for PII and credential-sensitive implementation work."
tags: [hermes, ai-agents, security, local-llm, privacy, devops]
categories: [AI, Security]
---

# Tightening Hermes Agent security for local sensitive work

I recently added a local model path to my Hermes setup.

The motivation was simple: some agent work should not go to a cloud model by default. If the task touches PII, credentials, local configuration, or private code that I only want inspected on the machine, a local model is a better default than sending the whole prompt to an external API.

But "local" is not the same as "safe".

That was the part I wanted to make explicit in the setup. A local model can still print secrets into logs. It can still write them into temporary files. It can still run tools that reach the network. It can still summarize a credential back to me in a chat transcript that lives on disk. Moving inference onto the box removes one data path, but it does not remove the rest of the agent surface.

This post is the cleaned-up version of what I changed.

No real tokens, private project names, or account identifiers are included here. The useful part is the posture: split planning from implementation, keep sensitive work local, restrict tools, audit the runtime surface, and make the watchdog complain when the setup drifts.

## The shape I wanted

For normal engineering work, I still want a strong cloud model in the loop. It is better at planning, review, architecture, and reading a messy situation.

For sensitive local implementation, I want a smaller job:

```text
Cloud model
  -> writes the plan, policy, and implementation spec
  -> reviews the final diff when it is safe to do so

Local model
  -> reads the local spec
  -> edits a small bounded set of files
  -> runs the exact verification command
  -> reports file paths and pass/fail status
```

That split matters. I do not want the local model designing credential policy or deciding which secrets are safe to expose. I want it doing narrow implementation work from a spec that already says what to do.

The local lane runs through a `llama-server` OpenAI-compatible endpoint on localhost:

```text
http://127.0.0.1:<local-port>/v1
```

In Hermes config, that becomes a named local model alias and the last fallback:

```yaml
model_aliases:
  local-sensitive-worker:
    provider: custom
    model: <local-model-name>
    base_url: http://127.0.0.1:<local-port>/v1

fallback_providers:
  - provider: <cloud-planning-provider>
    model: <cloud-planning-model>
  - provider: custom
    model: <local-model-name>
    base_url: http://127.0.0.1:<local-port>/v1
```

The exact model is less important than the boundary. In my case it is a small quantized GGUF behind `llama-server`, running locally on a modest CPU-only machine. It is not fast enough to be a general autonomous coding brain. It is good enough for small implementation tasks when the spec is clear.

## The benchmark changed the policy

Before trusting the local worker for anything sensitive, I tested it on boring code tasks.

The useful result was not that it passed a few tests. The useful result was learning where it should not be trusted.

The local worker was fine for:

- one small utility function with tests;
- a known bug fix with a focused verification command;
- a two or three file change where the desired behaviour was already written down;
- redaction-style tasks where the output should contain placeholders, not secrets.

It was not good for open-ended reasoning. In a few direct prompts, it spent token budget on hidden reasoning and returned little or no visible answer. That is not a model I want making security decisions.

So the policy became:

```text
Use the local model as a junior implementation worker.
Do not use it as the architect, security reviewer, or incident commander.
```

That is an important distinction for agent setups. The weaker model can still be useful if the job is shaped correctly.

## Three local modes

I added explicit modes to the local implementation wrapper.

```bash
python3 ~/.hermes/scripts/local-implementer.py \
  --mode safe-code \
  --workdir /path/to/project \
  --design IMPLEMENTATION.md \
  --verify 'python3 -m unittest -q'
```

The modes are deliberately plain.

`safe-code` is for ordinary bounded implementation. The local worker reads a spec, edits files, runs the verification command, and reports what changed.

`sensitive-local` is for private data or PII-adjacent work. It keeps the model local, restricts tools to file and terminal work, and tells the worker not to reproduce sensitive content unless the spec explicitly requires it.

`credential-hygiene` is stricter. It is for scanning or redacting secret-shaped values. The rule is simple: never print the full credential value. Replace it with `[REDACTED]`. Report the file path and category, not the token.

A credential hygiene task should end with a report like this:

```text
Changed files:
- app.log: replaced dummy API token with [REDACTED]
- verify.py: added local redaction check

Verification:
- python3 verify.py: PASS

Sensitive values printed:
- none
```

The wording is boring on purpose. Boring is good here.

## Tool access is part of the security boundary

The local model is not enough if it can call every tool.

For sensitive local work, I do not want browser, email, Drive, calendar, web search, or random MCP tools enabled. A local model with network tools can still exfiltrate data. A local model with email tools can still put sensitive text somewhere it should not go.

The default sensitive lane uses only local tools:

```text
file, terminal
```

Even that deserves care. Terminal access can print environment variables, inspect credential files, and write logs. The wrapper prompt therefore pushes the worker toward local edits and local verification, not exploratory dumping of state.

The more important rule is human: do not ask any model to summarize or display real secret values unless there is a very specific reason. Most credential tasks do not require that. They require finding, replacing, rotating, and testing that the secret is no longer present.

## Removing broad command approvals

The biggest tightening was not model-related.

My Hermes config already used manual approvals, but the command allowlist still included broad categories such as recursive delete, heredoc script execution, `python -c`-style execution, and `execute_code`.

That is convenient. It is also too permissive for a long-running agent connected to messaging, cron jobs, local files, and plugins.

I changed it to:

```yaml
approvals:
  mode: manual

command_allowlist: []
```

This does not make the system magically safe. It does remove a bad default. High-impact commands should come back through the approval path instead of sliding through because I got tired of confirming them last week.

I also updated the security watchdog so it alerts if those broad approvals return:

```text
WARN: command_allowlist contains high-risk broad approvals; prefer [] with approvals.mode manual
```

That is the pattern I like for personal infrastructure: do the safe thing once, then make drift noisy.

## Versioned setup, unversioned secrets

My Hermes home is versioned in Git, but only as a curated setup repo.

That means I track things like:

```text
config.yaml
skills/
plugins/
scripts/
cron/jobs.json
.githooks/
```

I do not track runtime state or credentials:

```text
.env
auth.json
sessions/
logs/
cache/
state.db
profiles/
```

The repo uses a deny-by-default `.gitignore`. Everything is ignored first, then intentional setup paths are allowed back in. That avoids the usual mistake where a new cache directory or token file quietly becomes eligible for commit.

Before commits, the hook runs a staged secret scan. It looks for token-shaped values and private keys without printing the value. That last part matters. A scanner that helpfully prints the secret has just created another leak.

The output I want is this boring line:

```text
Staged secret scan passed: 0 findings
```

## Outbound network audit

The other check is outbound URLs.

For a normal script, a new `https://...` literal might be harmless. For an agent runtime, it is part of the exfiltration surface. I want to know which hosts the versioned runtime can reach.

The audit scans tracked runtime files and separates two things:

- literal outbound hosts;
- dynamic network sinks such as `curl`, `requests`, `urllib`, `fetch`, or similar calls.

The expected runtime host list is narrow. Local model endpoints are localhost. External APIs are explicit and reviewed. Documentation can contain many URLs, but runtime scripts and config should not grow new network paths unnoticed.

That distinction avoids false panic while still catching the dangerous class of change.

## Cron jobs need least privilege too

Scheduled agents are easy to forget about because they run when I am not looking.

That makes cron jobs part of the security review. Each scheduled job should declare a small `enabled_toolsets` list. A briefing job that only needs web search should not have file access. A script-only watchdog should not wake up an LLM at all.

The watchdog checks for missing or broad toolsets and alerts on prompts that contain obviously sensitive or high-impact operation terms.

It is not trying to prove the prompt is safe. It is trying to stop silent expansion.

## The watchdog is intentionally quiet

The final piece is a script-only security watchdog.

It checks:

- tracked secret-shaped values;
- credential file permissions;
- outbound runtime hosts;
- high-risk command allowlist entries;
- Git hook installation;
- uncommitted setup drift;
- cron toolset posture;
- local sensitive lane readiness;
- MCP configuration for credential-mediated workspace access.

It prints nothing when healthy. If it finds something, it sends a concise alert.

That matters for signal. A daily "all good" message becomes noise after a week. Silence is the success path. Alerts should mean something changed.

## What this does not solve

This is not a complete sandbox.

The agent process still runs on a real machine. Local files still exist. Terminal tools are still powerful. A prompt-injected document can still try to steer the agent. Redaction can fail. A local model can still produce bad edits.

The stronger boundary is still a whole-process sandbox with filesystem and network policy. I wrote about that separately when looking at OpenShell. I still think that is the right direction for a remote, always-on agent that reads untrusted input.

This tightening is the layer I can apply today:

```text
local model for sensitive implementation
restricted tools for sensitive modes
manual approvals for dangerous commands
deny-by-default setup versioning
secret scans before commits
outbound host audits
quiet watchdog for drift
```

It is not perfect. It is much better than "the prompt says do not leak secrets."

## The useful lesson

The lesson from this pass is that agent security is mostly about boring boundaries.

Where can the model run? What tools can it call? Which files can be committed? Which hosts can scripts reach? Which commands need approval? Which jobs run when nobody is watching? Which values should never be displayed, even to me?

Local inference helps, but it is only one answer in that list.

For sensitive work, I now prefer this rule:

```text
Cloud model for policy and review.
Local model for bounded implementation.
No raw secrets in prompts, logs, commits, or final reports.
```

That is a small rule, but it changes how I use the agent. It makes the safe path explicit instead of relying on me to remember the safe path every time.
