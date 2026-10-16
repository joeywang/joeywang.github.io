---
layout: page
title: About
permalink: /about/
author_profile: true
description: "Joey Wang: senior software engineer focused on applied AI, agent workflows, systems integration, and reliable delivery."
---

[Download résumé (PDF)](/assets/pdf/JoeyW-dev.pdf) · [Read résumé online](/resume.html)

## Applied AI, built on production engineering

I'm Joey Wang, a senior software engineer with a background in Ruby on Rails, learning platforms, cloud infrastructure, and production reliability. My current focus is applied AI: connecting models, tools, and existing software to solve useful problems.

I'm interested in the gap between a promising demo and a solution people can depend on. A model endpoint is only one part of that work. The surrounding application needs clear boundaries, useful context, tests, and a way to recover when something fails.

## What I bring

- **Applied AI and agent workflows** — hands-on experiments with local models, coding agents, tool integration, and bounded engineering tasks. I document both working paths and limitations rather than treating an experiment as a production deployment.
- **Systems integration** — experience connecting application features, APIs, databases, and delivery infrastructure. At Kitman Labs, I also collaborated with data scientists on integrating machine learning models and predictive analytics features.
- **Rails and learning-platform engineering** — architecture, application development, and incremental modernization of long-lived systems.
- **Production reliability** — performance investigation, PostgreSQL, cloud delivery, testing, and operational feedback that helps a team understand what changed.

## How I approach a problem

I start with the people using the system and the workflow they need to complete. Then I inspect the code, data, and operational constraints before choosing an implementation. Sometimes AI is useful; sometimes a deterministic integration is the better answer.

My preferred delivery loop is to:

1. understand the problem and agree what a useful result would look like;
2. identify integration constraints, risks, and a small first slice;
3. implement it and check the result against explicit criteria;
4. document limitations, human approval points, and recovery steps.

That is what draws me toward **Forward Deployed Engineering (FDE)**: staying close to the user's problem while taking responsibility for implementation, integration, and the feedback needed to improve it. It is a direction for my work, not a replacement title for my previous roles.

## Selected work and experiments

- [Local coding-agent integration]({% post_url 2026-04-21-lm-studio-local-agent-runbook %}) — wiring an OpenAI-compatible model endpoint into agent clients, checking the integration, and troubleshooting runtime constraints.
- [Testing small local LLMs]({% post_url 2026-08-12-portable-local-llm-benchmark %}) — a repeatable workflow for checking task output and runtime behavior on modest hardware.
- [Durable codebase context]({% post_url 2026-07-18-durable-codebase-context-hermes-gitnexus-lsp %}) — combining code relationships, semantic diagnostics, and stable project instructions for engineering agents.
- [Rails and LMS modernization]({% post_url 2026-08-13-rails-lms-reliability-modernization %}) — diagnosing platform friction before committing to a rewrite.

## What I'm interested in

Applied AI and FDE opportunities where I can combine hands-on software delivery with understanding users' problems. My strongest contribution is the engineering around the model: integrations, context, verification, and reliable operation.

This site includes completed engineering work, experiments, and developing ideas. I try to keep those categories distinct and show the evidence behind each claim.

For a conversation about applied AI, integrations, or an established Rails or learning platform, [get in touch](/consulting/).
