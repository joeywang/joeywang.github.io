---
layout: post
title: "Redis Memory Spikes: Tracking Down a Runaway Sidekiq Queue"
date:   2024-07-01 14:41:26 +0100
pin: true
categories: Rails
description: "How I traced a Redis memory jump from 130MB to 800MB back to an unthrottled Sidekiq integration, and the maxmemory, eviction, and unique-job fixes that followed."
tags: [redis, sidekiq, rails, debugging, performance]
---

Redis memory on one of our services jumped from 130MB to 800MB. My first suspect was the Rails cache. It wasn't. This is the trail from the symptom to the actual cause, an unthrottled Sidekiq integration, and what I changed afterwards.

## Confirming the surge

`INFO memory` confirmed the numbers:

```plaintext
used_memory:843019880
used_memory_human:803.97M
used_memory_rss:902520832
used_memory_rss_human:860.71M
```

## The configuration problem underneath

Before hunting for the source, I checked how Redis was configured to behave under memory pressure. Badly, as it turned out:

```bash
CONFIG GET maxmemory
1) "maxmemory"
2) "0"

CONFIG GET maxmemory-policy
1) "maxmemory-policy"
2) "noeviction"
```

No memory ceiling and no eviction policy. Redis would grow until the host ran out of RAM. I set a limit and an eviction policy:

```bash
CONFIG SET maxmemory 1024m
CONFIG SET maxmemory-policy volatile-lru
```

One warning here: never set `maxmemory` below current usage. With `noeviction`, or with nothing evictable, Redis starts refusing writes immediately and you have turned a slow leak into an outage.

## Finding the source

`INFO keyspace` showed where the memory actually lived:

```plaintext
db0:keys=34,expires=0,avg_ttl=0
db1:keys=754,expires=719,avg_ttl=0
db2:keys=8924,expires=8864,avg_ttl=0
db3:keys=117156,expires=117140,avg_ttl=0
```

Over 117,000 keys in db3, the database Sidekiq uses. This was not a cache problem. It was a job queue problem.

## The Sidekiq overflow

A month earlier we had shipped an integration between two of our apps: App A indexed active users and App B pulled their details and updated records. There was no concurrency control on the Sidekiq side, so the integration enqueued thousands of jobs at once, and every queued job sits in Redis until it runs.

The obvious options were:

1. Limit concurrent jobs per queue.
2. Throttle how many jobs run within a given period.

I chose throttling and underestimated the consequence: jobs were enqueued faster than the throttled workers could drain them, so the queue kept growing and Redis memory grew with it. Throttling the workers does nothing if you do not also throttle the producer.

## What actually fixed it

1. Tuned the throttle parameters against the real enqueue rate, not a guess.
2. Deduplicated: only users whose details had actually changed get a job.
3. Used Sidekiq's unique-jobs support so the same user cannot be queued twice.

Longer term, the pull model itself is the weak point. Webhooks from App A pushing changes to App B would remove most of these jobs entirely, and a circuit breaker would stop a bad deploy from filling the queue again.

## The lesson

Sidekiq makes it trivially cheap to enqueue work, and that is exactly the danger: every queued job is memory in Redis, and an unbounded producer with a throttled consumer is a memory leak with extra steps. Set `maxmemory` and an eviction policy before you need them, and treat enqueue rate as something you design, not something that happens to you.
