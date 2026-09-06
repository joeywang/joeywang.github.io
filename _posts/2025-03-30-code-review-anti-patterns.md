---
layout: post
title: "Code Review Anti-Patterns That Waste the Most Time"
description: "The code review anti-patterns that slow teams down most: giant PRs, style-war comments, and reviews that skip the business context entirely."
date: 2025-03-30
tags: [code-review, testing, ci, productivity]
categories: [Engineering]
---
<audio controls preload="metadata" src="/assets/audio/code-review-anti-patterns-summary.ogg">
  Your browser does not support the audio element.
</audio>

### Code review anti-patterns that waste the most time

Most bad code review isn't a skill problem. It's a handful of habits that repeat across teams, and each one has a fix that's cheaper than living with it.

**Style wars in the comments.** Arguing about brace placement or import order in a PR thread is a tell that linting isn't wired into CI. Push ESLint, Black, Prettier, whatever fits the stack, into the pipeline so the reviewer never sees a style issue in the first place. That frees the review for the things a linter can't check: is this the right approach, does it handle the edge case, does it belong here at all.

**PRs too large to actually review.** A 900-line diff gets a skim and an approve, not a review. Reviewers either rubber-stamp it or spend hours on it and still miss things, because holding that much context in your head at once isn't something people are good at. Break the work into pieces a reviewer can hold in their head: one behavior change, one migration, one refactor at a time.

**Threads that run forever.** Two rounds of back-and-forth on a comment is normal. A fifth round on the same line is a sign the disagreement is not about the code, it's about something that needs a five-minute call to resolve. Move it there before it eats a day of async latency.

**Reviewing the diff without the reason.** A reviewer who doesn't know why a change exists can only check that it compiles, not that it's the right change. Link the ticket. Write the "why" in the PR description, not just the "what."

**Skipping security and scale to focus on correctness.** Code that works today and falls over at ten times the load, or leaks data under the wrong input, passed review because nobody asked those questions. They need to be part of the checklist, not an afterthought raised after an incident.

None of this is about being a harsher reviewer. It's about automating what a machine can check, keeping the unit of review small enough to actually read, and making sure the reviewer has the context to judge the change, not just the diff.
