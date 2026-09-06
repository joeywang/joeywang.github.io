---
title: "From 499 to 200: Fixing Nginx Timeouts in a Rails API"
date: 2025-09-17
author: "Joey Wang"
description: "How Puma worker timeouts and Nginx 499 errors expose slow Rails requests, and how to fix them with aligned timeouts, background jobs, and caching."
tags: [rails, puma, nginx, devops, performance]
categories: [Rails, DevOps]
---

<audio controls preload="metadata" src="/assets/audio/nginx-499-timeout-summary.ogg">
  Your browser does not support the audio element.
</audio>

A spike in HTTP 499s in your Nginx logs feels mysterious: "the client closed the connection before the server responded." But a 499 isn't random, it's a signal that some layer of your stack is slower than the client's patience. Here's why it happens and how to fix it.

---

## The Request Stack

A typical Rails + Puma + Nginx stack looks like this:

```

Browser → CDN → Nginx → Puma → Rails → DB / Redis / External API

````

If any layer takes longer than the timeout of the layer above, the client gives up.  
That’s when Nginx logs a `499`.

---

## Anatomy of a Slow Request

```ruby
# app/controllers/demo_controller.rb
class DemoController < ApplicationController
  def cpu_heavy
    render json: { result: (1..50_000_000).sum }
  end

  def io_heavy
    render json: { result: Net::HTTP.get(URI('https://httpbin.org/delay/3')) }
  end
end
````

* **CPU-bound**: blocks the Ruby GVL and stalls other threads.
* **I/O-bound**: wastes time waiting for slow dependencies.

---

## Quick Mitigations

### 1. Align Timeouts (Stop Early Cutoffs)

**Puma** (`config/puma.rb`):

```ruby
workers ENV.fetch("WEB_CONCURRENCY") { 4 }
threads_count = ENV.fetch("RAILS_MAX_THREADS") { 8 }
threads threads_count, threads_count
worker_timeout 60
force_shutdown_after 10
```

**Nginx**:

```nginx
proxy_connect_timeout 5s;
proxy_send_timeout 60s;
proxy_read_timeout 60s;
send_timeout 60s;
```

Keep client/CDN timeouts slightly shorter.

---

### 2. Move Long Work to Background Jobs

```ruby
class ReportJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find(user_id)
    ReportGenerator.generate_for(user)
  end
end

def create
  ReportJob.perform_later(current_user.id)
  render json: { status: "queued" }, status: :accepted
end
```

Return `202 Accepted` and let Sidekiq or Resque do the work.

---

### 3. Cache Expensive Reads

```ruby
def index
  @articles = Rails.cache.fetch("articles:index", expires_in: 10.minutes) do
    Article.includes(:author).order(created_at: :desc).limit(100).to_a
  end
  render json: @articles
end
```

Add `ETag` and `Cache-Control` headers for even better CDN caching.

---

## Long-Term Improvements

### 1. Separate CPU vs IO Pools

**Procfile**

```bash
web_io: bundle exec puma -C config/puma.io.rb
web_cpu: bundle exec puma -C config/puma.cpu.rb
```

**Nginx routing**

```nginx
location /reports/ { proxy_pass http://app_cpu; proxy_read_timeout 180; }
location /api/     { proxy_pass http://app_io;  proxy_read_timeout 30;  }
```

CPU tasks won’t block I/O threads anymore.

---

### 2. Tune Connection Pools

Ensure DB pool ≥ Puma max threads:

```yaml
production:
  database:
    pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 8 } %>
```

---

### 3. Prewarm Caches

Warm caches during deploy:

```bash
curl -s https://example.com/api/popular?page=1 > /dev/null
```

---

### 4. Observability

```ruby
Rack::Timeout.service_timeout = 25
```

Monitor:

* p95/p99 latency
* 499 rate
* Puma thread saturation
* DB pool waits

---

## Timeout Hierarchy (Balanced Setup)

| Layer                      | Example Timeout | Purpose              |
| -------------------------- | --------------- | -------------------- |
| Client/CDN                 | 30s             | User patience        |
| Nginx `proxy_read_timeout` | 60s             | Buffer for app       |
| Rack::Timeout              | 25s             | Safety cutoff        |
| DB/HTTP client             | 10–20s          | Fail fast            |
| Puma `worker_timeout`      | 60s             | Detect stuck workers |

---

## Quick vs Long-Term Fixes

| Type      | Actions                                      | Goal               |
| --------- | -------------------------------------------- | ------------------ |
| Quick     | Align timeouts, cache, async jobs            | Stop 499s          |
| Mid-Term  | Split pools, prewarm, tune DB                | Boost reliability  |
| Long-Term | Add tracing, circuit breakers, load shedding | Prevent regression |

---

## The judgment

HTTP 499s aren't bugs, they're signals: something in the stack is slower than your user's patience. Track request IDs so you can trace a 499 back to the layer that caused it, alert on the 499 rate itself rather than just latency percentiles, and work through the table above in order, quick fixes first. Most 499 spikes trace back to one slow query or one synchronous call that should have been a background job; find that before reaching for circuit breakers.
