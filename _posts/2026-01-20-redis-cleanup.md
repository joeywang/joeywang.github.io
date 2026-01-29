---
layout: post
title: "Redis Cleanup & Memory Management in Kubernetes"
date: 2026-01-20 10:00:00 -0500
categories: redis kubernetes sidekiq

# Redis Cleanup & Memory Management in Kubernetes

This article is a **practical, production-tested guide** to keeping Redis healthy in a **Kubernetes (K8s)** environment. It focuses on **memory control, cleanup strategies, Sidekiq-specific pitfalls, safe deletion scripts, backups, and troubleshooting**.

It is written for engineers who:

* Run Redis in K8s (StatefulSet, Helm, managed Redis, or sidecar)
* Use Redis for **cache, background jobs (Sidekiq), sessions, or ephemeral data**
* Have experienced **memory spikes, fragmentation, or Redis OOM incidents**

---

## 1. Core Principles (Read This First)

Before touching any cleanup script, internalize these rules:

1. **Redis memory issues are almost always caused by retention mistakes, not leaks**
2. **KEYS *** is forbidden in production
3. **DEL is dangerous for large keys — UNLINK is preferred**
4. **Backups must come before cleanup**
5. **TTL is the only sustainable memory strategy**

If Redis data can grow forever, it eventually will.

---

## 2. Redis in Kubernetes: What Makes It Tricky

Kubernetes adds unique failure modes:

* Pods can restart unexpectedly → memory spikes repeat
* RSS vs used_memory confusion in container limits
* Eviction by the kubelet if Redis exceeds memory limits
* PersistentVolumes hide real memory growth

### Recommendation

* Always set **Redis pod memory limits**
* Always configure **Redis maxmemory**
* Never rely on K8s eviction alone

---

## 3. Baseline Health Checks (Run These First)

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

This tells you **where keys live**, not how large they are.

---

## 4. The Silent Killers: Large Keys

Redis is fast — until you store **huge values**.

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

---

## 5. Backups Before Cleanup (Non‑Negotiable)

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

Why this works:

* Handles very large keys
* Fast
* Easy restore

---

## 6. Safe Cleanup Patterns

### Rule: UNLINK > DEL

`DEL` blocks Redis while freeing memory.
`UNLINK` frees memory asynchronously.

---

### Pattern 1: Delete keys by pattern

```bash
DB=0

redis-cli -n "$DB" --scan MATCH 'Course#linked_course_uuids_and_self*' \
| while read -r key; do
    redis-cli -n "$DB" UNLINK "$key"
  done
```

---

### Pattern 2: Rate-limited cleanup (extra safe)

```bash
DB=0

redis-cli -n "$DB" --scan MATCH 'stat:*' \
| while read -r key; do
    redis-cli -n "$DB" UNLINK "$key"
    sleep 0.01
  done
```

---

## 7. Sidekiq: The Biggest Redis Memory Trap

### Why Sidekiq causes Redis memory explosions

By default:

* `stat:*` keys **never expire**
* Retry jobs accumulate
* Dead jobs remain for months

This is expected behavior — and dangerous without tuning.

---

### Fix 1: Apply TTL to Sidekiq stats

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

---

### Fix 2: Reduce retry pressure

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

---

### Fix 3: Tune dead job retention

```ruby
Sidekiq.configure_server do |config|
  config.options[:dead_timeout] = 30 * 24 * 60 * 60
  config.options[:dead_max_jobs] = 2000
end
```

---

## 8. Redis maxmemory (K8s Safety Net)

Unbounded Redis is dangerous in containers.

### Recommended baseline

```bash
redis-cli CONFIG SET maxmemory 512mb
redis-cli CONFIG SET maxmemory-policy allkeys-lru
```

Choose a value **below your pod memory limit**.

---

## 9. Fragmentation & RSS Troubleshooting

### When RSS is much higher than used_memory

Run:

```bash
redis-cli MEMORY DOCTOR
```

If caused by historical peak:

* Harmless
* RSS will be reused

Try:

```bash
redis-cli MEMORY PURGE
```

Guaranteed fix:

* Rolling restart

---

## 10. Production Troubleshooting Checklist

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

---

## 11. Kubernetes-Specific Recommendations

* Use **StatefulSet** for Redis
* Set **resources.limits.memory**
* Avoid OOMKills by setting Redis maxmemory
* Prefer managed Redis for critical workloads

---

## 12. Final Takeaways

* Redis problems are **predictable**
* TTL beats cleanup scripts
* UNLINK beats DEL
* Backups beat regret
* Sidekiq defaults are not production-safe

If you fix retention, Redis becomes boring again — and boring is good.

---

If you want, this guide can be adapted into:

* An internal runbook
* A Helm chart checklist
* A Sidekiq-specific hardening guide
* A Grafana alerting spec

Just say the word.
