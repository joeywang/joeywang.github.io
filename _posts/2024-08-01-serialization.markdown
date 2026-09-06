---
layout: post
title: "Speeding Up Nested JSON Serialization in Rails"
description: "Caching, the Oj gem, eager loading, background jobs, and load_async each cut serialization time for deeply nested Rails associations like classrooms and scores."
date:   2024-08-01 14:41:26 +0100
pin: true
categories: Rails
tags: [rails, ruby, performance, database]
---

Serializing a deeply nested structure, classrooms to students to lessons to exercises to scores, is where Rails starts to slow down. Fetching it in one request means walking every layer, and each layer that isn't eager-loaded turns into its own round trip to the database. A few techniques, used together, keep this fast.

## Cache the parts that don't change often

Scores and exercises are the most frequently requested part of this structure and, once an exercise is graded, the least likely to change. Caching at the fragment or action level means serving the previous response instead of rebuilding it:

- Use Rails' built-in caching, or Redis for finer-grained control over what gets invalidated and when.
- Cache scores and exercises specifically, they're the layer with the best hit rate.

## A faster serializer: Oj

`Oj` outperforms Ruby's default `JSON` library for generating large JSON payloads.

```ruby
# Gemfile
gem 'oj'
```

```ruby
Oj.dump(data)  # instead of JSON.generate(data)
```

## Eager loading to avoid N+1 queries

The nested structure above is a textbook N+1 problem: querying each classroom's students, then each student's lessons, one query at a time. Preload the whole chain instead:

```ruby
ClassRoom.includes(students: { lessons: { exercises: :scores } }).where(teacher_id: 1)
```

## Background serialization with Sidekiq

If the payload is expensive to build and doesn't need to be real-time, build it outside the request cycle. A Sidekiq worker can serialize the data on a schedule or on write, and store the result for the next read to pick up, so nobody's request pays the full cost of the nested query.

## Parallel loading with load_async

Rails' `load_async`, combined with `Concurrent::Async`, lets independent associations load concurrently instead of sequentially:

```ruby
ClassRoom.find(1).load_async.students.load_async.lessons
```

This helps most when the associations being loaded are independent of each other, loading students and a separate summary table in parallel, for example, rather than a strict parent-child chain.

## What's left

These five techniques compose: eager load to avoid N+1, cache the parts that repeat, use a faster serializer for the parts that don't, and push anything expensive and non-urgent into the background. Beyond that, pagination to cap payload depth and response compression are the next levers, and profiling the actual request is what tells you which one to pull first.
