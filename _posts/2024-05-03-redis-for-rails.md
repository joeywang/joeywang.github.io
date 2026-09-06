---
layout: post
title:  "Redis in Ruby on Rails: Cache Server and Job Queue"
description: "Redis serves two very different roles in a Rails app, a disposable read cache and a durable job queue, and conflating the two causes real outages."
date:   2024-05-03 14:41:26 +0100
categories: [Rails, DevOps]
tags: [redis, rails, sidekiq, performance]
---

<audio controls preload="metadata" src="/assets/audio/redis-for-rails-summary.ogg">
  Your browser does not support the audio element.
</audio>


Redis serves two different roles in a Rails app: a cache and a job queue. Treating them the same is where the trouble starts.

## Redis as a cache server

- Read-heavy workload: built for frequent reads.
- Regenerable data: only cache what you can recreate on a miss.
- No persistence needed: the cache can be rebuilt from source at any time.

`redis.get` is not automatically faster than a PostgreSQL query. Depending on the query and the network hop, a well-indexed Postgres lookup can beat a Redis round trip.

## Redis as a job queue

- Persistence matters here: a crash should not silently drop queued jobs.
- Jobs can be split across queues by priority.
- Sidekiq Pro adds reliability guarantees the open-source version doesn't have.

## Metrics worth watching

- Memory usage.
- I/O rate.
- Active connections.
- Hit rate, for the cache use case specifically.

## Getting more out of it

- Use connection pools on both the Rails and Sidekiq sides.
- Use Redis's C extension for faster connections.
- Run Sentinel or cluster mode if you need HA.
- Check whether a managed Redis is actually cheaper than the ops cost of running your own.
- Split queues by workload: CPU-heavy jobs separate from I/O-heavy ones.
- Run separate Redis instances for caching and queuing. A read-heavy cache workload and a write-heavy queue workload fight each other on the same instance.

## Tuning under load

- Scale Redis capacity ahead of expected load, not after you've seen it fail.
- Decommission Redis instances that have become unreliable rather than working around them.
- Fall back to Sidekiq's inline mode if Redis becomes unresponsive, so jobs still run in a degraded state.
- Tune connection, retry, read, and write timeouts to match what your app can tolerate.

## The part that actually matters

None of this helps without knowing your own traffic: what your requests look like and what your jobs actually do. Redis is only one lever. Puma's process and thread counts matter just as much for how much load the app can take before Redis becomes the bottleneck.
