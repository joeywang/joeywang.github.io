---
layout: post
title: "Redis Cleanup and Memory Management in Kubernetes"
description: "A production-tested guide to keeping Redis healthy in Kubernetes: memory control, safe cleanup patterns, Sidekiq pitfalls, backups, and troubleshooting."
date: 2026-01-20 10:00:00 -0500
categories: [Database, DevOps]
tags: [redis, kubernetes, sidekiq, devops, performance]
---

This is a practical, production-tested guide to keeping Redis healthy in Kubernetes, covering memory control, cleanup strategies, Sidekiq-specific pitfalls, safe deletion scripts, backups, and troubleshooting. It's written for anyone running Redis in K8s (StatefulSet, Helm, managed Redis, or sidecar) for cache, background jobs, sessions, or ephemeral data, who has already hit a memory spike, fragmentation, or an OOM incident.

## 1. Core principles

Before touching any cleanup script, internalize these rules: Redis memory issues are almost always caused by retention mistakes, not leaks. `KEYS *` is forbidden in production. `DEL` is dangerous for large keys, `UNLINK` is preferred. Backups come before cleanup. TTL is the only sustainable memory strategy.

If Redis data can grow forever, it eventually will.

## 2. Redis in Kubernetes: what makes it tricky

Kubernetes adds unique failure modes:

* Pods can restart unexpectedly → memory spikes repeat
* RSS vs used_memory confusion in container limits
* Eviction by the kubelet if Redis exceeds memory limits
* PersistentVolumes hide real memory growth

### Recommendation

Always set Redis pod memory limits, always configure Redis `maxmemory`, and never rely on K8s eviction alone.

## 3. Baseline health checks

### Memory overview

```bash
redis-cli INFO memory
```

Key fields:

* `used_memory_human`
* `used_memory_rss_human`
* `mem_fragmentation_ratio`
* `maxmemory`
* `maxmemory_policy`

### Keyspace overview

```bash
redis-cli INFO keyspace
```

This tells you where keys live, not how large they are.

## 4. The silent killer: large keys

Redis is fast until you store huge values.

Common offenders:

* `stat:*` (Sidekiq statistics)
* Large JSON strings
* Unbounded hashes or lists
* Job payloads stored as strings

### Find the biggest keys safely

```bash
DB=0
TOP=20

redis-cli -n "$DB" --scan \
| while read -r key; do
    bytes=$(redis-cli -n "$DB" MEMORY USAGE "$key" 2>/dev/null)
    [ -z "$bytes" ] && bytes=0
    printf "%12s  %s\n" "$bytes" "$key"
  done \
| sort -nr \
| head -n "$TOP"
```

Never use `KEYS *`.

## 5. Backups before cleanup

### Recommended: RDB snapshot

```bash
redis-cli BGSAVE
```

Locate and copy:

```bash
redis-cli CONFIG GET dir
redis-cli CONFIG GET dbfilename
cp /var/lib/redis/dump.rdb /backup/redis/pre-cleanup-$(date +%F).rdb
```

This handles very large keys, is fast, and gives an easy restore path.

## 6. Safe cleanup patterns

`DEL` blocks Redis while freeing memory. `UNLINK` frees memory asynchronously, so it's the one to reach for.

### Pattern 1: delete keys by pattern

```bash
DB=0

redis-cli -n "$DB" --scan MATCH 'Course#linked_course_uuids_and_self*' \
| while read -r key; do
    redis-cli -n "$DB" UNLINK "$key"
  done
```

### Pattern 2: rate-limited cleanup

```bash
DB=0

redis-cli -n "$DB" --scan MATCH 'stat:*' \
| while read -r key; do
    redis-cli -n "$DB" UNLINK "$key"
    sleep 0.01
  done
```

## 7. Sidekiq: the biggest Redis memory trap

By default, `stat:*` keys never expire, retry jobs accumulate, and dead jobs remain for months. This is expected behavior, and it's dangerous without tuning.

### Fix 1: apply TTL to Sidekiq stats

`config/initializers/sidekiq.rb`

```ruby
Sidekiq.configure_server do |config|
  config.on(:startup) do
    Sidekiq.redis do |conn|
      retention_days = 30
      ttl = retention_days * 24 * 60 * 60

      conn.scan_each(match: 'stat:*') do |key|
        conn.expire(key, ttl)
      end
    end
  end
end
```

### Fix 2: reduce retry pressure

```ruby
class MyWorker
  include Sidekiq::Worker
  sidekiq_options retry: 5
end
```

Disable retries for non-critical jobs:

```ruby
sidekiq_options retry: false
```

### Fix 3: tune dead job retention

```ruby
Sidekiq.configure_server do |config|
  config.options[:dead_timeout] = 30 * 24 * 60 * 60
  config.options[:dead_max_jobs] = 2000
end
```

## 8. Redis maxmemory as a Kubernetes safety net

Unbounded Redis is dangerous in containers.

```bash
redis-cli CONFIG SET maxmemory 512mb
redis-cli CONFIG SET maxmemory-policy allkeys-lru
```

Choose a value below the pod memory limit.

## 9. Fragmentation and RSS troubleshooting

When RSS is much higher than `used_memory`, run:

```bash
redis-cli MEMORY DOCTOR
```

If it's caused by a historical peak, it's harmless and the RSS will be reused. `redis-cli MEMORY PURGE` can help. A rolling restart is the guaranteed fix.

## 10. Production troubleshooting checklist

### Check eviction & hit rate

```bash
redis-cli INFO stats | egrep 'evicted_keys|expired_keys|keyspace_hits|keyspace_misses'
```

### Check retry & dead size

```bash
redis-cli ZCARD retry
redis-cli ZCARD dead
```

### Check biggest keys again after cleanup

```bash
redis-cli --scan | head -n 20
```

## 11. Kubernetes-specific recommendations

Use a StatefulSet for Redis, set `resources.limits.memory`, avoid OOMKills by setting Redis `maxmemory`, and prefer managed Redis for critical workloads.

Redis problems are predictable: TTL beats cleanup scripts, UNLINK beats DEL, backups beat regret, and Sidekiq's defaults are not production-safe out of the box. Fix retention and Redis goes back to being boring, which is exactly what you want from it.
