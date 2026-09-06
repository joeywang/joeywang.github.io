---
layout: post
title: "Redis Sentinel: How Automatic Failover Actually Works"
description: "How Redis Sentinel provides high availability: quorum-based monitoring, master election, automatic failover, and what your client applications must do to follow along."
date:   2024-07-10 14:41:26 +0100
categories: [Database]
tags: [redis, devops, database]
---
<audio controls preload="metadata" src="/assets/audio/redis-sentinel-mode-summary.ogg">
  Your browser does not support the audio element.
</audio>

<img alt="Redis Sentinel topology" src="/assets/img/re/redis-sentinel.png"/>

A single Redis instance is a single point of failure. Sentinel is Redis's own answer to that: a distributed set of monitor processes that watch your Redis servers and promote a replica when the master dies, without a human in the loop. Here is the shape of it.

## The moving parts

- **Sentinel instances.** You deploy at least three, so they can form a quorum and no single Sentinel failure takes down the monitoring itself.
- **One master.** All writes go to it. Everything else replicates from it.
- **Replicas.** They serve reads and stand by as failover candidates.

## What Sentinel does

The Sentinel processes continuously ping the master and its replicas. When the master stops responding for longer than the configured `down-after-milliseconds`, the Sentinels compare notes. Only when enough of them agree the master is down (the quorum) does a failover begin. That agreement step matters: it stops one Sentinel with a flaky network path from triggering an unnecessary failover.

The failover itself:

1. The Sentinels elect a new master from the healthy replicas, based on replication offset and configured priorities.
2. The remaining replicas are reconfigured to replicate from the new master.
3. Sentinel publishes the new topology so clients can redirect their writes.

## The part people forget: the client

Failover on the server side is only half the story. Your application cannot simply hold a connection to a fixed master address, because that address stops being the master. Sentinel-aware clients connect to the Sentinels first, ask "who is the master for this name", and re-ask after a disconnection. If your Redis library is not configured for Sentinel, you have high availability on the server and an outage in the app.

## When it is worth it

Sentinel earns its operational overhead when losing write capability for more than a few seconds is unacceptable. For a cache that can be cold-started, it is usually overkill. For Sidekiq queues or anything holding data you cannot regenerate, automatic failover is the difference between a blip and a paged human at 3am.
