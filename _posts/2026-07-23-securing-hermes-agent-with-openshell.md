---
layout: post
title: "Securing Hermes Agent with OpenShell"
date: 2026-07-23 09:57:13 +0100
author: "Joey Wang"
description: "Why I would run Hermes Agent inside OpenShell when the agent reads untrusted content, and how filesystem, network, process, and credential policy change the security model."
tags: [hermes, openshell, ai-agents, security, sandboxing, devops]
categories: [AI, Security]
---

# Securing Hermes Agent with OpenShell

<audio controls preload="metadata" src="/assets/audio/2026-07-23-securing-hermes-agent-with-openshell-summary.ogg">
  Your browser does not support the audio element.
</audio>

Hermes is most useful when it can do real work.

That is also exactly why its security model matters.

A toy chatbot can be isolated by not giving it tools. A useful agent is different. It can read files, run commands, search a repository, inspect logs, call APIs, use credentials, load skills, talk through Telegram, and continue working while I am away from the keyboard.

That is the point. It is also the risk.

The more an agent becomes part of the operating environment, the less comfortable I am relying only on prompts, approval dialogs, and regex-based secret redaction. Those are useful guardrails, but they are not a security boundary.

This is where [OpenShell](https://github.com/NVIDIA/OpenShell) becomes interesting.

OpenShell describes itself as a safe, private runtime for autonomous AI agents. The practical idea is simple: instead of only sandboxing a shell command after the agent has already started, run the agent session inside a policy-controlled environment. The sandbox owns filesystem access, network egress, process behavior, and credential injection.

For Hermes, that changes the posture from:

```text
Trust the agent process, try to make individual tools safer
```

to:

```text
Run the whole agent environment behind an operating boundary
```

That distinction matters.

## Shell sandboxing is useful, but it is not the whole agent

A lot of agent security discussion focuses on the terminal tool:

- should the agent be allowed to run `rm`?
- should it ask before `git push`?
- should shell output redact secrets?
- should commands run in Docker?

Those are good questions, but Hermes is more than a terminal wrapper.

A real Hermes session may use:

- shell commands
- Python code execution
- file tools
- MCP subprocesses
- plugins
- skills and skill scripts
- gateway adapters such as Telegram, Slack, or email
- cron jobs
- credentials held by the agent process

If only the shell is sandboxed, then shell commands are constrained, but anything that runs in the agent process is still inside the larger trust boundary.

That is not a criticism of shell sandboxing. It is still valuable. It prevents many accidental destructive operations and limits normal command execution. It is the right posture when the operator is trusted and the main concern is mistakes in commands.

But it is not the posture I want when the agent consumes untrusted input.

Untrusted input includes more than obviously malicious websites. It can be:

- a GitHub issue body
- a pull request description
- a README in an unfamiliar repository
- a support email
- a Slack or Telegram message
- an MCP server response
- generated code from another agent
- logs copied from a system I do not fully control

Once an agent is reading those surfaces, prompt injection stops being a novelty and becomes normal input hygiene. The question is not “can someone inject instructions?” The question is “what can the agent environment reach if that happens?”

## OpenShell wraps the environment, not just one command

Hermes' own security policy makes a useful distinction between terminal-backend isolation and whole-process wrapping.

Terminal-backend isolation constrains the places where tool execution happens. Whole-process wrapping puts the entire agent process tree inside the sandbox. That means shell, code execution, MCP subprocesses, plugin loading, hook dispatch, and skill loading are all under the same external policy.

OpenShell is designed for that second shape.

The protection layers are the important part:

| Layer | What I care about |
| --- | --- |
| Filesystem | The agent should not read or write arbitrary host paths. |
| Network | The agent should not be able to exfiltrate data to any random endpoint. |
| Process | The sandbox should block privilege escalation and dangerous process behavior. |
| Inference | Model API traffic can be routed through controlled backends rather than raw caller credentials. |
| Credentials | Secrets should be injected at runtime, not written into the sandbox filesystem. |

That is a much better model for a long-running agent.

It means I can still give Hermes useful abilities, but the default answer becomes “no” until a policy says otherwise.

## Default-deny network is the part I like most

The most underrated agent risk is network egress.

People often focus on whether an agent can delete a file. That matters. But if an agent can read something sensitive and make arbitrary outbound HTTP requests, deletion is not the only problem. Data can leave the machine.

OpenShell starts each sandbox with minimal outbound access. Then you open specific paths with policy.

The OpenShell quickstart demonstrates this with the GitHub API:

```bash
openshell sandbox create --name demo --no-auto-providers

# Inside the sandbox: blocked by default
curl -sS https://api.github.com/zen
# curl: (56) Received HTTP code 403 from proxy after CONNECT
```

Then a policy allows read-only access to `api.github.com` for `curl`:

```yaml
version: 1

filesystem_policy:
  include_workdir: true
  read_only: [/usr, /lib, /proc, /dev/urandom, /app, /etc, /var/log]
  read_write: [/sandbox, /tmp, /dev/null]

landlock:
  compatibility: best_effort

process:
  run_as_user: sandbox
  run_as_group: sandbox

network_policies:
  github_api:
    name: github-api-readonly
    endpoints:
      - host: api.github.com
        port: 443
        protocol: rest
        enforcement: enforce
        access: read-only
    binaries:
      - { path: /usr/bin/curl }
```

Apply it without restarting the sandbox:

```bash
openshell policy set demo \
  --policy examples/sandbox-policy-quickstart/policy.yaml \
  --wait
```

Now a read can work, while a write is blocked at the HTTP method/path layer.

That is the right kind of boring.

For a Hermes environment, the same idea becomes a policy question:

```text
Which domains does this agent actually need?
Which methods does it need?
Which binaries are allowed to make those calls?
Which paths can it read?
Which paths can it write?
Which credentials exist only at runtime?
```

That is a better conversation than “the prompt says do not leak secrets.”

## A Hermes setup I would actually trust

For a personal remote Hermes instance, I would split the system into profiles or deployments by risk.

The low-risk local profile can stay convenient:

```text
Hermes local profile
  -> my laptop
  -> broad repo access
  -> human sitting nearby
  -> mostly trusted input
```

The higher-risk remote or always-on profile should be stricter:

```text
Telegram / email / web input
  -> Hermes inside OpenShell
     -> selected workspace paths
     -> no host home-directory access
     -> no arbitrary outbound network
     -> credentials from provider store
     -> explicit allowlist for APIs
```

The difference is not that one Hermes is “safe” and the other is “unsafe.” The difference is that they solve different problems.

On my laptop, I may want the agent to work like a pair programmer. It can edit the current repository and run the test suite. I am present, and I can interrupt.

On a remote machine connected to messaging, email, webhooks, and scheduled jobs, the agent is closer to infrastructure. It needs a stronger boundary because it will eventually read content I did not write.

## Credentials should not be files the sandbox can copy

One of the easiest mistakes is to put every token in environment variables or dotfiles and then mount the whole home directory into the agent environment.

That is convenient, but it weakens the isolation story.

Hermes already separates configuration and secrets: normal settings belong in config, secrets belong in credential stores or environment-specific secret files. OpenShell pushes this further by using a Provider store and injecting credentials at sandbox creation/runtime instead of leaving them as files inside the sandbox filesystem.

That matters because file permissions are not enough if the agent can read the file.

A better posture is:

```text
Policy says what the sandbox can read
Provider store says which credentials enter the sandbox
Network policy says where those credentials can be used
```

Those three things should line up.

For example, if a Hermes profile only needs to read GitHub metadata, it should not receive cloud admin credentials. If it only needs a model provider token, it should not get the token for a deployment system. If it can access a source-control API, its network policy should not also allow arbitrary pastebin-style destinations.

The boring rule is: give the agent the smallest credential bundle that matches the task.

## Approval prompts are still useful

I do not want to give the impression that approval prompts are pointless.

They are useful. I like them.

A good approval gate catches accidental destructive commands. It slows down surprising actions. It gives the operator a final chance to notice “why is this command deleting that directory?”

But it is not a boundary.

Shell is too flexible for a denylist to be complete. Prompt-injected content can be subtle. A plugin or skill can run code outside the exact command text the operator is reviewing. Redaction can miss strings, and even perfect redaction in logs does not stop network exfiltration from inside the environment.

So my mental model is:

```text
OpenShell policy: hard boundary
Hermes approvals: mistake prevention
Secret redaction: display hygiene
Skills Guard: install-time review aid
Human review: final responsibility
```

Layered defenses are useful only when each layer has a clear job.

## What I would allow first

If I were building a secure Hermes profile from scratch, I would start with almost nothing.

Filesystem:

- read/write access to one workspace directory
- read-only access to installed runtime files
- no access to the host home directory by default
- no broad mount of `~/.ssh`, `~/.kube`, cloud config, browser profiles, or password stores

Network:

- model provider endpoints required by the configured model route
- source-control API reads if the agent reviews repositories
- package registries only when dependency installation is expected
- observability APIs only for the specific debugging profile
- no arbitrary outbound HTTPS

Credentials:

- one model credential bundle
- one source-control credential if needed
- separate cloud/production credentials only in a separate profile
- no production write credentials in a general assistant profile

Hermes features:

- separate profiles for separate trust zones
- explicit gateway caller allowlists
- command approval prompts left on
- skill and plugin review before install
- memory and session files treated as sensitive operational data

This is slower than “mount everything and trust the model.”

It is also the difference between an assistant and an unbounded remote-control process.

## Where this fits with Docker

Docker is still a good answer for many teams.

Hermes can run commands through a Docker backend, and Hermes can also run as a containerized process. That is often enough for a developer workstation or CI-like workflow where the main goal is to keep file writes and shell commands inside a known directory.

OpenShell is the heavier answer for the cases where I want policy around the whole agent session:

- long-running remote agents
- messaging gateways
- webhook-triggered agents
- agents reading email or web content
- agents using third-party MCP servers
- agents with production-adjacent read access
- environments where network egress needs to be explainable

I would not start every experiment with OpenShell. I would start there when the agent becomes part of the operating environment.

## The practical checklist

Before exposing a Hermes instance to real work, I would ask these questions:

1. **What input can reach the agent?**
   Local prompts are different from email, webhooks, public issues, or group chats.

2. **What can the agent read?**
   Repositories, logs, session history, memory, credentials, browser profiles, and home-directory files all count.

3. **What can the agent write?**
   Source code, config files, cron jobs, deployment manifests, and shell profiles all matter.

4. **Where can data leave?**
   If outbound network is open, any readable data is potentially movable.

5. **Which credentials are present?**
   Credentials should match the profile’s job, not the operator’s full account.

6. **What is the approval boundary?**
   Which actions require human confirmation, and which are impossible regardless of prompt?

7. **Can I prove the policy?**
   A good sandbox should produce boring evidence: denied network logs, failed writes outside allowed paths, and successful reads only where expected.

The last point is important. Security should not be a feeling. It should be testable.

## The main lesson

The more useful an agent becomes, the more it resembles a user account with memory, credentials, and automation.

That is powerful. It is also why “please be careful” is not a security model.

For Hermes, I still want the friendly workflow: Telegram messages, scheduled jobs, GitHub triage, code search, logs, and the ability to hand it real tasks.

But for a remote or production-adjacent environment, I want those abilities inside an operating boundary:

```text
Hermes gives the agent capability.
OpenShell defines the room those capabilities can operate in.
```

That is the combination I find promising: an agent that can be useful without needing the whole machine handed to it.
