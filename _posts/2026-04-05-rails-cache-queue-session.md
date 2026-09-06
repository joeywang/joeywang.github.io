---
layout: post
title:  "Redis High Availability: Shared Sessions and Fault Tolerance"
description: "How to split Redis into isolated session, cache, and Sidekiq instances so a cache blip never logs users out or stops background jobs."
date:   2026-04-05 10:00:00 -0400
categories: [Database, DevOps]
tags: [redis, rails, kubernetes, devops, database]
---

<audio controls preload="metadata" src="/assets/audio/rails-cache-queue-session-summary.ogg">
  Your browser does not support the audio element.
</audio>

In a multi-app architecture, Redis usually ends up as the glue: it holds sessions, speeds up pages via caching, and backs Sidekiq's job queue. The common mistake is treating all three as one instance. If that instance blips during a routine cloud provider node upgrade, the whole platform goes dark at once, because a session outage, a cache miss, and a stalled job queue are three different failure modes wearing the same name.

## Split Redis by function, not convenience

The fix is decoupling: three separate Redis groups (StatefulSets in Kubernetes), each with its own failure profile.

| Group | Data type | Priority | Failure impact |
| :--- | :--- | :--- | :--- |
| Session | User IDs, CSRF tokens | Critical | Users get logged out (full outage) |
| Cache | HTML fragments, API results | Medium | Site slows down (degraded performance) |
| Sidekiq | Background job metadata | High | Emails and uploads stop (data delay) |

Losing the cache instance should never mean losing sessions. Losing Sidekiq should never mean the site goes down. That only holds if they're actually separate.

## Shared sessions and how long to keep them

When sessions are shared across subdomains (`dashboard.example.com` and `learn.example.com`), a centralized Redis store is what keeps a user logged in as they move between them.

For most SaaS or education platforms, 2 to 4 hours is the right session duration. It covers a normal study or work session without forcing constant re-logins, and because the session lives server-side in Redis rather than in a plain cookie, you can revoke it instantly if a device is lost, something a pure CookieStore can't do.

## Building in the redundancy

### Pod anti-affinity

To keep a cloud provider's node upgrade from taking out all your Redis replicas at once, use pod anti-affinity so Kubernetes spreads them across different physical nodes:

```yaml
# Partial StatefulSet spec
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - redis-session
            topologyKey: "kubernetes.io/hostname"
```

### Fail soft in Rails config

A Redis connection error shouldn't produce a 500. Handle it and fall back instead:

**`config/environments/production.rb`**
```ruby
# 1. Resilient cache
config.cache_store = :redis_cache_store, {
  url: ENV['REDIS_CACHE_URL'],
  connect_timeout: 1,
  read_timeout: 0.2,
  error_handler: -> (method:, returning:, exception:) {
    Rails.logger.error "Redis Cache Down: #{exception.message}"
    returning # Returns nil, forcing a DB fetch instead of a crash
  }
}

# 2. Shared session store
Rails.application.config.session_store :redis_store,
  servers: [ENV['REDIS_SESSION_URL']],
  key: '_shared_org_session',
  domain: :all, # Allows subdomains to share the cookie
  expire_after: 4.hours
```

### A safety valve for Sidekiq

If the Sidekiq Redis instance is down, enqueuing a job shouldn't crash the web request:

**`app/jobs/application_job.rb`**
```ruby
class ApplicationJob < ActiveJob::Base
  # Detect if Redis is alive; if not, run the job immediately (inline)
  self.queue_adapter = begin
    Sidekiq.redis(&:ping)
    :sidekiq
  rescue StandardError => e
    Rails.logger.warn "Sidekiq Redis Unreachable: Falling back to :inline. #{e.message}"
    :inline
  end
end
```

## Auditing whether the memory is worth it

As the app grows, it's worth checking whether Redis memory usage is actually justified. This script finds the top memory-hogging keys in the current DB:

**`redis_audit.sh`**
```bash
#!/bin/bash
# Find the top 5 memory-consuming keys in the current DB
echo "Scanning for top memory consumers..."
redis-cli --scan | xargs -I {} redis-cli MEMORY USAGE {} | paste - - | sort -nr -k 2 | head -n 5 | awk '{printf "  %s bytes\t%s\n", $2, $1}'

# Summarize by data type
redis-cli --bigkeys | grep -E "summarized|payload"
```

## The mindset

None of this is exotic. It's isolation (a cache spike never logs a user out), redundancy (anti-affinity survives a node upgrade), and graceful degradation (if Redis fails, the code knows to skip the cache instead of crashing). Put together, that's the difference between a fragile single point of failure and infrastructure that stays up while one piece of it is having a bad day.
</content>
