---
layout: post
title: "Production Debugging Techniques for Rails Apps"
date:   2024-07-02 14:41:26 +0100
categories: Rails
description: "Practical production debugging techniques for Rails: log analysis, replicating production data, rbtrace live injection, feature-flagged debug modes, and replica apps."
tags: [rails, debugging, devops, kubernetes]
---

In an ideal world every production problem reproduces locally, gets debugged with pry, and ships as a patch in the next release. In practice, the bugs that matter are often the ones that refuse to reproduce anywhere but production. This post walks through the techniques I reach for, ordered from least invasive to most.

## Why production bugs resist reproduction

A few things make production different in ways that matter:

1. Data volume: production databases are larger and messier than anything in development.
2. Feature flags: different configurations may be active for different users.
3. Environment configuration: production has settings tuned for performance and security that other environments skip.
4. Customer-specific setups: some issues only occur for one customer's particular configuration.
5. Load and scale: concurrency bugs need concurrency to show up.

Staging tries to mimic production and usually falls short on exactly the dimensions that triggered the bug: request volume and data complexity.

## Before touching production

### Read the telemetry you already have

Tools like Sentry and Datadog often contain the answer if you look hard enough:

- Error logs and stack traces
- Request payloads and responses
- Performance metrics and anomalies

This only works if the logging was set up before the incident. Instrumentation added after the fire starts is archaeology, not observability.

### Replicate production data locally

Pull a subset of production data into your local environment:

```bash
pg_dump -h production-db-host -U username -d dbname -t specific_table > dump.sql
psql -d local_db < dump.sql
```

Pros:
- Full control over the environment
- Local debugging tools work (pry, byebug)

Cons:
- Slow for large databases
- Sensitive data now lives on a laptop, which your security team will have opinions about

### Port forwarding to a read replica

Connect your local app to the remote database instead of copying it:

```bash
ssh -L 5432:localhost:5432 user@production-server
```

Pros:
- No lengthy dump and restore
- Works against read-only replicas

Cons:
- Every query pays a network round trip
- Requires SSH access to production, which should be tightly controlled

## Staging techniques

### Simulate the user's exact path

- Log in as a system admin or impersonated user
- Replicate the exact steps that led to the issue
- Automate the reproduction with Capybara or Selenium so you can rerun it after each fix attempt

### rbtrace: inject code into a running process

rbtrace lets you attach to a live Ruby process and run code inside it:

```ruby
# Enable rbtrace in your Gemfile
gem 'rbtrace'

# In your Puma config
plugin 'rbtrace'

# Connect to the process
rbtrace -p <PID>

# Inject debugging code
TracePoint.new(:call) do |tp|
  puts "#{tp.defined_class}##{tp.method_id} called"
end.enable
```

Things that will bite you if you skip them:

- rbtrace must be enabled via environment variables
- Injected changes are temporary and vanish on process restart
- Run Puma in single mode, or you will attach to one worker while your requests hit another
- Verify your test requests actually reach the debugged process

## Debugging in production itself

When nothing else reproduces the problem, you debug where it lives. Carefully.

### Targeted logging

Add detailed logging scoped to the affected user or scenario:

```ruby
if current_user.email == "problematic_user@example.com"
  Rails.logger.debug "Detailed info: #{some_object.inspect}"
end
```

### Feature-flagged debug modes

Flags let you switch verbose diagnostics on for one user without a deploy to turn them off:

```ruby
if Flipper.enabled?(:debug_mode, current_user)
  # Additional debugging logic
end
```

### A replica app behind the load balancer

For the truly stubborn cases: run a replica of the production app, route only the affected requests to it, and apply heavier instrumentation there without touching the traffic everyone else sees.

Example Kubernetes service targeting the debug deployment:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: debug-service
spec:
  selector:
    app: myapp
    version: debug
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9376
```

## The principle

Escalate deliberately: telemetry first, local reproduction second, staging third, production last. The goal in production is to gather enough information to reproduce the bug somewhere safer, not to fix it live. Every technique that touches production trades some risk to users for information, so make sure the information is worth it.
