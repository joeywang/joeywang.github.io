---
layout: post
title: "Production Ruby Debugging: A Progressive Escalation Guide"
date: 2026-05-29
author: "Joey Wang"
description: "Comprehensive guide to debugging Ruby applications in Kubernetes production without restarting: rbspy, kubectl debug, signals, puma handlers, rbtrace, and gdb"
tags: [Ruby, Kubernetes, Debugging, Production, rbspy, rbtrace, gdb, DevOps, SRE]
---

# Production Ruby Debugging: A Progressive Escalation Guide

## The Production Debugging Dilemma

It's 2 AM. Your API latency just spiked from 200ms to 30 seconds. Customer support is getting complaints. The on-call dashboard is a sea of red.

Your first instinct? Restart the pods. But wait—this is the third spike this week. Restarting buys you an hour before it happens again. You need answers, not temporary relief.

The problem: your Ruby application is running in Kubernetes, handling real traffic, with real customer data. You can't just attach a debugger or start printing to stdout. You need to investigate *without disrupting service*.

This guide documents six levels of Ruby debugging techniques, organized from least to most invasive. Each level gives you progressively more power—and more risk. Learn when to use each tool, how to use it safely, and when to escalate to the next level.

## The Escalation Principle

Start with the safest, least invasive tool. If it doesn't give you enough information, escalate to the next level. Don't reach for gdb when rbspy will do.

**The Six Levels:**

1. **Level 1: rbspy** 🔍 - Non-invasive sampling profiler
2. **Level 2: kubectl debug** 🔍 - Infrastructure access via ephemeral containers  
3. **Level 3: kill signals** ⚡ - Unix signal-based stack traces
4. **Level 4: puma signal handlers** 🎯 - Application-level diagnostics
5. **Level 5: rbtrace** ⚠️ - Runtime code injection
6. **Level 6: gdb** 🚨 - System-level C debugging

## How to Use This Guide

- **In an incident?** Start at Level 1, escalate as needed
- **Building a runbook?** Read all six levels to understand your options
- **New to production debugging?** Read sequentially to learn the progression

Each level is self-contained with installation, usage, examples, and safety guidelines. Let's begin.

## Prerequisites & Safety First 🛡️

Before diving into debugging, ensure you have the right setup and understand the risks.

### Required Tools Summary

**Level 1-2 (Low Risk):**
- rbspy: `brew install rbspy` or `cargo install rbspy`
- kubectl: Version 1.18+ (for `kubectl debug`)
- Kubernetes access: Pod exec permissions

**Level 3-4 (Medium Risk):**
- Shell access to pods: `kubectl exec` permissions
- Understanding of Unix signals
- Log access: `kubectl logs` permissions

**Level 5-6 (High Risk):**
- rbtrace: `gem install rbtrace` (requires msgpack)
- gdb: `apt-get install gdb ruby-debug` or `yum install gdb ruby-debuginfo`
- Process debugging permissions (may require privileged containers)

### Kubernetes Permissions Required

Minimum RBAC permissions for debugging:

```yaml
# Read-only debugging (Level 1-2)
- apiGroups: [""]
  resources: ["pods", "pods/log"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods/ephemeralcontainers"]
  verbs: ["patch"]

# Interactive debugging (Level 3-5)
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
```

### Production Safety Guidelines

**Before you start:**

1. **Communicate:** Notify your team you're debugging. Document what you're doing.
2. **Have a rollback plan:** Know how to restart the pod if something goes wrong.
3. **Start safe:** Always begin at Level 1. Only escalate if necessary.
4. **Time-box investigation:** Set a limit (30 minutes). If you're not making progress, escalate or restart.
5. **Monitor impact:** Watch pod CPU/memory while debugging. If it spikes, stop immediately.

**Risk Matrix:**

| Level | Tool | Invasiveness | Can Crash Process? | Overhead | Safe in Production? |
|-------|------|--------------|-------------------|----------|---------------------|
| 1 | rbspy | Low | No | <1% CPU | ✅ Yes |
| 2 | kubectl debug | Low | No | Sidecar resources | ✅ Yes |
| 3 | kill signals | Medium | Rarely (bad handler) | None | ⚠️ Usually |
| 4 | puma handlers | Medium | Rarely (bad code) | Depends on handler | ⚠️ Usually |
| 5 | rbtrace | High | Yes (bad injection) | Can pause execution | ⚠️ With caution |
| 6 | gdb | Very High | Yes (wrong command) | Can pause execution | 🚨 Last resort only |

**When to restart instead of debug:**

- You've been debugging for >30 minutes without progress
- The issue is actively causing customer impact you can't tolerate
- You've reached Level 6 and still don't have answers (time to collect a core dump and restart)
- Your team doesn't have experience with the higher-level tools

Now let's dig into the tools, starting with the safest option.

## Level 1: Non-Invasive Observation 🔍

### What is rbspy?

rbspy is a sampling profiler for Ruby that works by reading process memory without attaching to the process or requiring any instrumentation. Unlike traditional profilers that inject code or use debugging APIs, rbspy observes from the outside, making it completely safe for production use.

Think of rbspy as looking through a window into your Ruby process—you can see what's happening, but you're not interfering with its operation. This makes it the perfect starting point for any production debugging session.

**How it works:** rbspy reads the Ruby process's stack from `/proc/<pid>/mem` (Linux) or equivalent system APIs. It samples the stack at regular intervals (default: 100Hz) and aggregates the results into a profile.

### 🎯 When to Use rbspy

Start here for:
- **CPU usage investigations** - See which methods are consuming CPU time
- **First-pass profiling** - Get a quick overview before deeper investigation
- **Safe observability** - When you need zero risk to the running process
- **Comparative analysis** - Profile the same endpoint across multiple pods to find outliers

### Prerequisites

**Installation:**

```bash
# macOS
brew install rbspy

# Linux (from source)
cargo install rbspy

# Or download binary
wget https://github.com/rbspy/rbspy/releases/download/v0.12.0/rbspy-x86_64-unknown-linux-musl.tar.gz
tar xf rbspy-x86_64-unknown-linux-musl.tar.gz
```

**Permissions:**
- Read access to `/proc/<pid>/mem` (usually requires same UID as Ruby process or root)
- In Kubernetes: May require privileged container or `SYS_PTRACE` capability

### Basic Usage

**Core commands:**

```bash
# Snapshot: Single stack trace (fastest, safest)
rbspy snapshot --pid <PID>

# Record: Profile for duration, generate report
rbspy record --pid <PID> --duration 30

# Record with flamegraph output
rbspy record --pid <PID> --duration 30 --file profile.svg

# Record raw data for later analysis
rbspy record --pid <PID> --duration 30 --raw-file profile.raw.gz
```

**In Kubernetes:**

```bash
# Find the pod and get a shell
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash

# Find Ruby process PID
ps aux | grep ruby

# Run rbspy (if installed in container)
rbspy snapshot --pid <PID>
```

### Example 1: CPU Usage Investigation

**Scenario:** API response time is slow (2-3 seconds instead of 200ms).

**Step 1:** Get a snapshot to see what's running right now:

```bash
$ rbspy snapshot --pid 42

% self  % total  name
 67.2%   67.2%    ActiveRecord::QueryMethods#where
 15.3%   82.5%    Array#each
  8.1%   90.6%    JSON.parse
  4.2%   94.8%    String#gsub
```

**Interpretation:** 67% of time is spent in `ActiveRecord::QueryMethods#where`. This is a database query issue, not application code.

**Step 2:** Record a longer profile to get more data:

```bash
$ rbspy record --pid 42 --duration 60 --file profile.svg

Wrote data to profile.svg
Run `open profile.svg` to view
```

**Step 3:** Open flamegraph (copy from pod if needed):

```bash
kubectl cp <pod-name>:/path/to/profile.svg ./profile.svg
open profile.svg
```

**Flamegraph shows:** 
- Wide bar at bottom: `where` clause
- Multiple narrow bars: N+1 queries (loop calling `where` repeatedly)

**Resolution:** Found N+1 query problem. Fix with eager loading: `.includes(:association)`.

### Example 2: Comparing Healthy vs Slow Pods

**Scenario:** Some pods are fast, others are slow. Which code path differs?

**Step 1:** Profile fast pod:

```bash
kubectl exec -it fast-pod-abc -- rbspy record --pid $(pgrep ruby) --duration 30 --file /tmp/fast.svg
kubectl cp fast-pod-abc:/tmp/fast.svg ./fast.svg
```

**Step 2:** Profile slow pod:

```bash
kubectl exec -it slow-pod-xyz -- rbspy record --pid $(pgrep ruby) --duration 30 --file /tmp/slow.svg
kubectl cp slow-pod-xyz:/tmp/slow.svg ./slow.svg
```

**Step 3:** Compare flamegraphs visually:
- Fast pod: Top method is `ProductsController#index` (expected)
- Slow pod: Top method is `Rack::Lint#call` (50% of time!)

**Interpretation:** Slow pod has Rack::Lint enabled in production (should only be in development). Configuration issue, not code issue.

### Reading rbspy Output

**Text output format:**

```
% self    % total   name
75.0%     75.0%     MyClass#slow_method
15.0%     90.0%     Array#map
10.0%     100.0%    Kernel#sleep
```

- **% self**: Time spent directly in this method (excluding called methods)
- **% total**: Cumulative time including called methods
- **name**: Method name in Ruby format

**What to look for:**
- High % self in unexpected methods (your smoking gun)
- Many small % self entries (overhead from too many calls)
- High % total at top of stack (hot path confirmed)

**Flamegraph format:**
- Width = time spent (wider = more time)
- Height = call depth (bottom = entry point, top = deepest call)
- Color = randomly assigned for visibility (no meaning)
- Click boxes to zoom into subgraphs

### 🚨 Common Gotchas

**Issue 1: "Permission denied" error**

```bash
$ rbspy snapshot --pid 42
Error: Permission denied (os error 13)
```

**Fix:** rbspy needs to read process memory. Options:
```bash
# Run as root
sudo rbspy snapshot --pid 42

# Or give rbspy CAP_SYS_PTRACE capability
sudo setcap cap_sys_ptrace+ep $(which rbspy)
rbspy snapshot --pid 42
```

**In Kubernetes:** May need privileged container or add `SYS_PTRACE` to securityContext.

**Issue 2: "Process not found"**

Usually PID changed (process restarted). Find current PID:
```bash
ps aux | grep ruby
pgrep -f puma  # or whatever your app server is
```

**Issue 3: Flamegraph is too noisy**

Profile for longer to get more samples:
```bash
# Default: 30 seconds might not be enough
rbspy record --pid 42 --duration 120  # 2 minutes

# Or increase sample rate (higher CPU overhead)
rbspy record --pid 42 --rate 200  # 200Hz instead of 100Hz
```

**Issue 4: rbspy not installed in production container**

Two options:
1. Use `kubectl debug` (Level 2) to add rbspy via sidecar
2. Copy rbspy binary into running container:
   ```bash
   kubectl cp rbspy <pod>:/tmp/rbspy
   kubectl exec <pod> -- chmod +x /tmp/rbspy
   kubectl exec <pod> -- /tmp/rbspy snapshot --pid $(pgrep ruby)
   ```

### 🛡️ Production Safety

**Invasiveness:** Low (non-invasive observation)  
**Overhead:** <1% CPU, minimal memory  
**Risks:** None (read-only memory access)  
**Reversibility:** N/A (doesn't modify anything)

rbspy is the safest tool in this guide. It can't crash your process, slow it down significantly, or interfere with its operation. The only risk is the tiny CPU overhead from sampling.

**Safe for:**
- Production pods under heavy load
- Profiling without customer notification
- Long-duration recording (hours)
- Automated monitoring (run periodically)

**Performance impact:**
- Sampling overhead: <1% CPU at 100Hz
- Memory: ~10MB for rbspy process itself
- I/O: Minimal (reading process memory)

### ⏭️ When to Escalate to Level 2

Move to kubectl debug when:
- rbspy isn't installed in your container and you can't easily add it
- You need to run rbspy with different versions/flags for testing
- You want access to the pod's filesystem for other investigation
- rbspy gives you a clue but you need to inspect files/config

Move to Level 3+ when:
- rbspy shows even CPU usage (no hot spots) but latency is high → might be I/O or blocking
- rbspy shows time in native code (C extensions) that you need to debug
- You need more than statistical sampling (need precise traces)

**Level 1 Key Takeaways:**
- ✅ When to use: CPU investigation, first-pass profiling, safe observability
- ⚡ Impact: <1% CPU overhead, zero risk
- 📊 Info gained: Statistical CPU profile, method call frequency
- ⏭️ Escalate when: rbspy unavailable, need filesystem access, or need deeper inspection

## Level 2: Safe Infrastructure Access 🔍

### What is kubectl debug?

`kubectl debug` (Kubernetes 1.18+) creates ephemeral containers that share the process namespace and filesystem with your application pod. This lets you add debugging tools without modifying your production container image.

Think of it as spawning a diagnostic sidecar that can see everything your app sees—processes, filesystems, network—but lives in a separate container that you can delete without touching your application.

**How it works:** kubectl debug creates a new container in an existing pod with `shareProcessNamespace: true`. This new container sees all processes from the original container, including their memory maps and file descriptors.

### 🎯 When to Use kubectl debug

Use this when:
- rbspy or other debug tools aren't in your production container
- You need filesystem access to inspect logs, config, or temp files
- You want to test debugging commands without modifying your image
- You need a clean shell with common utilities (curl, netstat, strace)

**Advantage over rebuilding the image:** kubectl debug gives you immediate access. No CI/CD pipeline, no deployment, no waiting.

### Prerequisites

**Kubernetes version:** 1.18+ (check with `kubectl version`)

**Permissions:**
```yaml
- apiGroups: [""]
  resources: ["pods/ephemeralcontainers"]
  verbs: ["patch"]
```

**Image choice:** Use an image with debugging tools. Options:
- `ubuntu:22.04` - Full utilities, large image (~77MB)
- `busybox` - Minimal, tiny (~1MB), limited tools
- `nicolaka/netshoot` - Network debugging focus
- Custom debug image with rbspy, strace, etc. pre-installed

### Basic Usage

**Create a debug container:**

```bash
# Basic: Spawn bash in a debug container
kubectl debug -it <pod-name> -n <namespace> \
  --image=ubuntu:22.04 \
  --target=<container-name> \
  -- /bin/bash

# With custom name
kubectl debug -it <pod-name> \
  --image=ubuntu:22.04 \
  --target=<container-name> \
  --container=debugger \
  -- /bin/bash

# Copy pod with debug container (creates new pod)
kubectl debug <pod-name> -it \
  --image=ubuntu:22.04 \
  --copy-to=<pod-name>-debug \
  -- /bin/bash
```

**Inside the debug container:**

```bash
# List all processes (you'll see app container's processes)
ps aux

# Find Ruby process
ps aux | grep ruby
pgrep -af ruby

# Install rbspy (if not in debug image)
apt-get update && apt-get install -y wget
wget https://github.com/rbspy/rbspy/releases/download/v0.12.0/rbspy-x86_64-unknown-linux-musl.tar.gz
tar xf rbspy*.tar.gz
./rbspy snapshot --pid <PID>

# Access app container's filesystem
ls -la /proc/<PID>/root/  # App container's root filesystem
cat /proc/<PID>/root/app/config/puma.rb

# Network investigation
apt-get install -y curl net-tools
netstat -tuln  # Check listening ports
curl localhost:3000/health  # Test local endpoint
```

### Example 1: Installing and Running rbspy via kubectl debug

**Scenario:** Your production container doesn't have rbspy, and you need to profile it now.

**Step 1:** Create debug container:

```bash
$ kubectl debug -it api-pod-7d8f9-abc \
  --image=ubuntu:22.04 \
  --target=api \
  -- /bin/bash

Defaulting debug container name to debugger-xxxxx.
If you don't see a command prompt, try pressing enter.

root@api-pod-7d8f9-abc:/#
```

**Step 2:** Install rbspy in the debug container:

```bash
root@api-pod-7d8f9-abc:/# apt-get update && apt-get install -y wget
root@api-pod-7d8f9-abc:/# wget https://github.com/rbspy/rbspy/releases/download/v0.12.0/rbspy-x86_64-unknown-linux-musl.tar.gz
root@api-pod-7d8f9-abc:/# tar xf rbspy*.tar.gz
root@api-pod-7d8f9-abc:/# chmod +x rbspy
```

**Step 3:** Find Ruby process PID:

```bash
root@api-pod-7d8f9-abc:/# ps aux | grep puma
app   42  0.5  2.1  1234567  87654  ?  Ssl  10:23  0:45  puma 5.6.4 (tcp://0.0.0.0:3000)
```

**Step 4:** Profile with rbspy:

```bash
root@api-pod-7d8f9-abc:/# ./rbspy snapshot --pid 42

% self  % total  name
 45.2%   45.2%    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter#execute
 23.1%   68.3%    ApplicationController#authenticate_user
 15.4%   83.7%    Rack::CommonLogger#call
```

**Step 5:** Exit (debug container is removed automatically):

```bash
root@api-pod-7d8f9-abc:/# exit
```

**Result:** Profiled production pod without modifying the image or restarting anything.

### Example 2: Inspecting Application Files

**Scenario:** Suspect a misconfiguration. Need to check what config files actually look like in production.

**Step 1:** Create debug container:

```bash
kubectl debug -it api-pod-7d8f9-abc --image=ubuntu:22.04 --target=api -- /bin/bash
```

**Step 2:** Find app container's filesystem:

```bash
# Find Ruby process PID
ps aux | grep ruby
# PID: 42

# Access its root filesystem
cd /proc/42/root

# Now you're seeing the app container's files
ls -la
# Output: app/ config/ Gemfile Gemfile.lock ...

cat config/database.yml
# Check what DB config is actually loaded

cat .env
# Check environment variables (if .env file exists)
```

**Step 3:** Check for unexpected files:

```bash
# Are there old log files taking up space?
du -sh /proc/42/root/log/*

# Are there temp files from a failed migration?
ls -la /proc/42/root/tmp/

# Is there a PID file preventing restart?
ls -la /proc/42/root/tmp/pids/
```

**Result:** Found that `DATABASE_URL` in `.env` was pointing to the wrong RDS instance. Configuration issue, not code.

### Example 3: Network Debugging

**Scenario:** Application can't reach external API (timeouts), but curl from laptop works fine.

**Step 1:** Create debug container with network tools:

```bash
kubectl debug -it api-pod-7d8f9-abc \
  --image=nicolaka/netshoot \
  --target=api \
  -- /bin/bash
```

**Step 2:** Test connectivity from pod's network namespace:

```bash
# Test DNS resolution
nslookup external-api.example.com
# Output: Returns IP (DNS works)

# Test TCP connection
nc -zv external-api.example.com 443
# Output: Connection refused (firewall issue?)

# Test from same VPC but outside pod
curl -v https://external-api.example.com
# Works from node, fails from pod
```

**Step 3:** Check network policies:

```bash
# List iptables rules (if privileged)
iptables -L -n

# Or exit and check from kubectl
kubectl get networkpolicies -n <namespace>
```

**Result:** Found Kubernetes NetworkPolicy blocking egress to that external API. Policy fix, not app fix.

### 🚨 Common Gotchas

**Issue 1: "Ephemeral containers not supported"**

```bash
error: ephemeral containers are disabled for this cluster
```

**Fix:** Kubernetes version < 1.18. Options:
- Upgrade cluster
- Use `kubectl exec` with existing container instead (Level 3+)
- Build debugging tools into your image

**Issue 2: Debug container can't see app processes**

```bash
root@pod:/# ps aux
# Only shows debug container's processes
```

**Fix:** Missing `--target` flag. Recreate with:
```bash
kubectl debug -it <pod> --image=ubuntu:22.04 --target=<container-name> -- /bin/bash
```

**Issue 3: "target container not found"**

Wrong container name. List containers in pod:
```bash
kubectl get pod <pod-name> -o jsonpath='{.spec.containers[*].name}'
```

**Issue 4: Debug container uses too many resources**

Large debug image (ubuntu) competes with app for resources. Solutions:
- Use smaller image: `busybox` or `alpine`
- Set resource limits:
  ```bash
  kubectl debug <pod> --image=ubuntu:22.04 \
    --image-pull-policy=IfNotPresent \
    --set-resource-limits="cpu=100m,memory=128Mi" \
    -- /bin/bash
  ```

### 🛡️ Production Safety

**Invasiveness:** Low (separate container, shared view)  
**Overhead:** Sidecar resources (typically 100m CPU, 128Mi memory)  
**Risks:** Resource contention (if debug container uses too much)  
**Reversibility:** High (exit and debug container is removed)

kubectl debug is very safe. The debug container runs separately and can be killed without affecting your app.

**Safe for:**
- Production debugging anytime
- Long-running investigation (hours)
- Multiple concurrent debug sessions (different pods)

**Performance impact:**
- CPU/memory: Depends on debug image size and what you run
- Network: None (unless you run network-intensive commands)
- Storage: Ephemeral container image pulled once per node

**Cleanup:**
The ephemeral container is automatically removed when you exit the shell. However, if you used `--copy-to`, you created a new pod that you must delete:

```bash
kubectl delete pod <pod-name>-debug
```

### ⏭️ When to Escalate to Level 3

Move to kill signals when:
- You need stack traces for ALL threads, not just CPU samples
- You suspect deadlock or locking issues (rbspy won't show locks)
- You want instant feedback without installing tools
- The app has built-in signal handlers you want to trigger

Move to Level 4+ when:
- You need custom diagnostics (connection pool status, cache stats)
- You want to inject code for live inspection
- rbspy shows time in unexpected methods and you need more detail

**Level 2 Key Takeaways:**
- ✅ When to use: Debug tools not in container, filesystem inspection, network debugging
- ⚡ Impact: Sidecar resource overhead (~100m CPU, 128Mi memory)
- 📊 Info gained: Full filesystem access, ability to run any tool, network inspection
- ⏭️ Escalate when: Need thread dumps, built-in signal handlers, or custom diagnostics

## Level 3: Signal-Based Introspection ⚡

### What are Kill Signals?

Unix signals are software interrupts that let you communicate with running processes. In Ruby, you can send signals to trigger specific behaviors like dumping stack traces, without stopping or restarting the process.

**Key signals for Ruby debugging:**
- **SIGINFO** (Ctrl+T) - Print thread backtraces (BSD/macOS only)
- **SIGUSR1** - User-defined signal 1 (custom handlers)
- **SIGUSR2** - User-defined signal 2 (custom handlers)
- **SIGQUIT** - Dump stack and exit (last resort)

Think of signals as knocking on your application's door with different patterns—each knock triggers a different response.

**How it works:** When Ruby receives a signal, it interrupts the current execution and runs the registered signal handler. By default, Ruby prints stack traces for some signals. You can also register custom handlers (Level 4).

### 🎯 When to Use Kill Signals

Use signals when:
- You need stack traces RIGHT NOW (faster than installing rbspy)
- You suspect a deadlock or thread is hung
- You want to see ALL threads, not just CPU-active ones (rbspy only shows CPU usage)
- Your application already has custom signal handlers built in

**Advantage over rbspy:** Signals show you every thread's current state, including threads blocked on I/O, locks, or sleep. rbspy only samples threads that are using CPU.

### Prerequisites

**Permissions:**
- Shell access to pod: `kubectl exec` permissions
- Ability to find process PID
- Access to pod logs: `kubectl logs` permissions

**No installation required:** Signals are built into Unix/Linux.

### Basic Usage

**Send a signal:**

```bash
# Find the PID
ps aux | grep ruby

# Send signal
kill -USR1 <PID>   # User signal 1
kill -USR2 <PID>   # User signal 2
kill -QUIT <PID>   # Quit (dump and exit)
```

**In Kubernetes:**

```bash
# Find PID from within the pod
kubectl exec <pod-name> -- ps aux | grep ruby

# Send signal
kubectl exec <pod-name> -- kill -USR1 <PID>

# View resulting output in logs
kubectl logs <pod-name> --tail=100
```

### Example 1: Get Stack Traces for Hanging Requests

**Scenario:** Requests are timing out after 30 seconds. No CPU spike (rbspy shows nothing), but something is blocking.

**Step 1:** Send SIGUSR1 to trigger stack dump:

```bash
# From within pod or via kubectl exec
$ kill -USR1 42

# Check logs
$ kubectl logs api-pod-7d8f9-abc --tail=50

Thread TID-abc123 (main thread):
  /app/controllers/users_controller.rb:45:in `block in index'
  /gems/activerecord-7.0.4/lib/active_record/relation.rb:23:in `load'
  /gems/activerecord-7.0.4/lib/active_record/connection_adapters/abstract_adapter.rb:123:in `execute'
  /gems/pg-1.3.5/lib/pg/connection.rb:78:in `wait_for_result'
  
Thread TID-def456 (worker thread 2):
  /gems/puma-5.6.4/lib/puma/thread_pool.rb:89:in `sleep'
  
Thread TID-ghi789 (worker thread 3):
  /gems/rack-2.2.6/lib/rack/lock.rb:16:in `synchronize'
  /app/middleware/request_logger.rb:12:in `call'
```

**Interpretation:**
- Main thread is waiting on PostgreSQL query (`wait_for_result`)
- This is a slow query issue, not a Ruby code issue

**Step 2:** Send signal again 5 seconds later to confirm:

```bash
$ kill -USR1 42
# Check logs again
```

If the stack trace is identical, the thread is genuinely stuck (not just slow).

**Resolution:** Check PostgreSQL for long-running query: `SELECT * FROM pg_stat_activity WHERE state = 'active' AND query_start < NOW() - INTERVAL '30 seconds';`

### Example 2: Detecting Deadlock

**Scenario:** Application stops processing requests. CPU is idle. No errors in logs.

**Step 1:** Send signal and look for lock contention:

```bash
$ kubectl exec api-pod-7d8f9-abc -- kill -USR1 $(pgrep ruby)
$ kubectl logs api-pod-7d8f9-abc --tail=100

Thread TID-1 (main):
  /app/services/order_processor.rb:34:in `synchronize'  # Waiting for lock A
  /app/models/order.rb:67:in `update_inventory'
  
Thread TID-2 (worker):
  /app/services/inventory_manager.rb:23:in `synchronize'  # Waiting for lock B
  /app/services/order_processor.rb:45:in `finalize_order'

Thread TID-3 (worker):
  /gems/puma-5.6.4/lib/puma/thread_pool.rb:89:in `sleep'  # Idle, not part of deadlock
```

**Interpretation:**
- Thread 1 holds lock A, waiting for lock B
- Thread 2 holds lock B, waiting for lock A
- Classic deadlock between OrderProcessor and InventoryManager

**Resolution:** Fix locking order in code (always acquire locks in same order) or use a timeout:

```ruby
# Bad (can deadlock)
lock_a.synchronize { lock_b.synchronize { ... } }

# Good (consistent order)
[lock_a, lock_b].sort_by(&:object_id).each { |lock| lock.synchronize { ... } }

# Or use timeout
Timeout.timeout(5) { lock_a.synchronize { ... } }
```

### Example 3: Finding Slow Middleware

**Scenario:** Every request is slow by exactly 5 seconds. No obvious hot spots in rbspy.

**Step 1:** Send signal during a request:

```bash
# Trigger request in another terminal
curl https://api.example.com/users &

# Immediately send signal
kubectl exec <pod> -- kill -USR1 $(pgrep ruby)
kubectl logs <pod> --tail=50

Thread TID-main:
  /gems/rack-2.2.6/lib/rack/sleep.rb:8:in `sleep'  # <-- There's the culprit
  /app/middleware/artificial_delay.rb:12:in `call'
  /app/config.ru:23:in `call'
```

**Interpretation:** There's a middleware called `artificial_delay` that's sleeping for 5 seconds. Probably a debug middleware left in production by accident.

**Resolution:** Check `config.ru` or middleware stack, remove the delay middleware.

### Default Ruby Signal Handlers

Ruby has built-in handlers for some signals:

| Signal | Default Behavior | Safe in Production? |
|--------|------------------|---------------------|
| SIGUSR1 | No default handler (safe to override) | ✅ Yes |
| SIGUSR2 | No default handler (safe to override) | ✅ Yes |
| SIGQUIT | Print stack traces and exit | ⚠️ Only if you can tolerate pod restart |
| SIGINFO | Print stack traces (BSD/macOS only) | ✅ Yes (if available) |
| SIGTERM | Graceful shutdown | 🚨 No (Kubernetes uses this for pod termination) |
| SIGKILL | Immediate kill (cannot be caught) | 🚨 Never |

**Note:** If your application registers custom handlers (Level 4), these defaults may be overridden.

### 🚨 Common Gotchas

**Issue 1: Signal does nothing**

```bash
$ kill -USR1 42
# No output in logs
```

**Possible causes:**
- Wrong PID (process restarted)
- Application registered a custom handler that doesn't log
- Logs are being buffered (try: `kubectl logs -f` to stream)

**Fix:** 
```bash
# Verify PID is correct
ps aux | grep ruby

# Try SIGQUIT (dumps and exits)
kill -QUIT 42  # ⚠️ This will restart the pod
```

**Issue 2: "Permission denied" when sending signal**

```bash
$ kill -USR1 42
kill: (42) - Operation not permitted
```

**Fix:** Need to run as same user as Ruby process or root:
```bash
kubectl exec <pod> -- su app -c "kill -USR1 42"
# or
kubectl exec --user=app <pod> -- kill -USR1 42
```

**Issue 3: Signal output not in logs**

Ruby may be writing to stderr instead of stdout, or using a different log file.

**Fix:**
```bash
# Check both stdout and stderr
kubectl logs <pod> --tail=100
kubectl logs <pod> --previous --tail=100  # Previous container (if restarted)

# Or exec into pod and check files directly
kubectl exec <pod> -- cat /app/log/production.log
```

**Issue 4: SIGINFO doesn't work (Linux)**

SIGINFO is BSD/macOS only. Linux doesn't support it.

**Fix:** Use SIGUSR1 or SIGUSR2 instead, and register a custom handler (Level 4) to print stack traces.

### 🛡️ Production Safety

**Invasiveness:** Medium (interrupts execution briefly)  
**Overhead:** Minimal (< 1ms to handle signal)  
**Risks:** Can crash if handler has bugs; SIGQUIT terminates process  
**Reversibility:** High (signal is one-time event)

Signals are generally safe, but with caveats:

**Safe signals:**
- SIGUSR1, SIGUSR2 (user-defined, no default dangerous behavior)
- SIGINFO (BSD only, prints stacks)

**Risky signals:**
- SIGQUIT (dumps and exits)
- SIGTERM (graceful shutdown - Kubernetes uses this)
- SIGKILL (immediate kill, cannot be caught)

**Custom handlers add risk:** If your app has a custom signal handler (Level 4) with bugs, sending the signal could crash the process.

**Performance impact:**
- Handler execution: <1ms typically
- Stack trace printing: 10-50ms (depends on thread count)
- No ongoing overhead (signal is one-time)

### ⏭️ When to Escalate to Level 4

Move to custom puma handlers when:
- Default signal behavior doesn't give you enough information
- You want application-specific diagnostics (connection pool, cache, custom metrics)
- You want to trigger behavior without redeploying (e.g., clear cache on SIGUSR1)
- You want structured output (JSON) instead of raw stack traces

Move to Level 5+ when:
- Stack traces show the location but you need to inspect variable values
- You need to run Ruby code inside the process to check state
- Signals reveal a problem but you need live debugging to fix it

**Level 3 Key Takeaways:**
- ✅ When to use: Quick stack traces, thread dumps, deadlock detection
- ⚡ Impact: <1ms to handle signal, no ongoing overhead
- 📊 Info gained: All threads' current stack traces, including I/O-blocked threads
- ⏭️ Escalate when: Need custom diagnostics, variable inspection, or live debugging

*(Continuing in next message due to length...)*

## Level 4: Application-Level Handlers 🎯

### What are Puma Signal Handlers?

Puma and other Ruby application servers let you register custom signal handlers that run application-specific diagnostics. Instead of relying on default behaviors (Level 3), you define exactly what information to gather when a signal arrives.

Think of this as teaching your application new tricks: "When I send USR1, dump thread info AND connection pool status AND memory stats." Custom handlers turn signals into powerful diagnostic triggers.

**How it works:** In `config/puma.rb`, you register Ruby code to run when specific signals arrive. This code has full access to your application's runtime state.

### 🎯 When to Use Custom Signal Handlers

Use custom handlers when:
- You need application-specific diagnostics (connection pools, cache hit rates, job queue depth)
- Default stack traces don't give you enough context
- You want structured output (JSON) for automated monitoring
- You want to trigger actions (clear cache, rotate logs) without redeployment

**Advantage over default signals:** You control exactly what information is gathered and how it's formatted.

###Prerequisites

**Requires:**
- Access to `config/puma.rb` or equivalent application server config
- Ability to redeploy application (handlers are defined at boot time)
- Understanding of what diagnostics would be useful for your app

**One-time setup:** Add handlers to config, deploy, then use signals anytime.

### Basic Pattern

**In `config/puma.rb`:**

```ruby
# Register handler for SIGUSR1
Signal.trap('USR1') do
  # Custom diagnostic code goes here
  Rails.logger.info "=== Custom Diagnostic Dump ==="
  Rails.logger.info "Timestamp: #{Time.now.iso8601}"
  
  # Add your custom logic
  Rails.logger.info "Thread count: #{Thread.list.size}"
  Rails.logger.info "Active connections: #{ActiveRecord::Base.connection_pool.stat}"
  
  Rails.logger.info "=== End Diagnostic Dump ==="
end

# Register handler for SIGUSR2 (different purpose)
Signal.trap('USR2') do
  # Maybe trigger a cache clear
  Rails.cache.clear
  Rails.logger.info "Cache cleared via SIGUSR2"
end
```

**Usage:**

```bash
# Deploy the new config
# (requires restart, but only once)

# Later, trigger diagnostics anytime
kubectl exec <pod> -- kill -USR1 $(pgrep ruby)
kubectl logs <pod> --tail=50
```

### Example: Comprehensive Diagnostic Handler

**Goal:** Get full application state dump on demand.

**Add to `config/puma.rb`:**

```ruby
Signal.trap('USR1') do
  require 'json'
  
  diagnostics = {
    timestamp: Time.now.iso8601,
    process: {
      pid: Process.pid,
      memory_mb: (`ps -o rss= -p #{Process.pid}`.to_i / 1024).round(2)
    },
    threads: {
      total: Thread.list.size,
      alive: Thread.list.count(&:alive?),
      backtrace: Thread.list.map { |t| 
        { 
          id: t.object_id, 
          status: t.status,
          backtrace: t.backtrace&.first(5)
        }
      }
    },
    database: ActiveRecord::Base.connection_pool.stat,
    gc: GC.stat.slice(:count, :heap_live_slots, :heap_free_slots, :total_allocated_objects),
    environment: {
      rails_env: Rails.env,
      rails_version: Rails.version,
      ruby_version: RUBY_VERSION
    }
  }
  
  Rails.logger.info "=== DIAGNOSTIC DUMP ==="
  Rails.logger.info JSON.pretty_generate(diagnostics)
  Rails.logger.info "=== END DUMP ==="
rescue => e
  Rails.logger.error "Error in USR1 handler: #{e.message}"
  Rails.logger.error e.backtrace.join("\n")
end
```

### 🛡️ Production Safety

**Invasiveness:** Medium (runs custom code in production)  
**Overhead:** Depends on handler code (keep it <100ms)  
**Risks:** Buggy handler can crash process; slow handler blocks requests  
**Reversibility:** High (one-time trigger, no persistent state change)

**Safe practices:**
- Wrap ALL handler code in begin/rescue
- Keep execution time under 100ms
- Use logger, not stdout/stderr directly
- Test handlers in staging first
- Avoid mutating state (just observe and log)

### ⏭️ When to Escalate to Level 5

Move to rbtrace when:
- Signal handlers show the problem area, but you need to inspect actual variable values
- You need to dynamically run Ruby code without redeploying
- You want to trace method calls in real-time

**Level 4 Key Takeaways:**
- ✅ When to use: Application-specific diagnostics, structured output, on-demand actions
- ⚡ Impact: Depends on handler code; keep under 100ms
- 📊 Info gained: Custom metrics (connection pools, job queues, cache stats, anything you code)
- ⏭️ Escalate when: Need variable inspection, dynamic code execution, or C-level debugging

## Level 5: Runtime Code Injection ⚠️

### What is rbtrace?

rbtrace is a Ruby gem that attaches to a running Ruby process and lets you execute arbitrary Ruby code inside it. Unlike signals (which trigger predefined handlers) or profilers (which only observe), rbtrace gives you a REPL-like interface into your production process.

Think of it as SSH-ing directly into your Ruby VM. You can inspect variables, call methods, trace function calls, and gather any information you can express in Ruby code—all while the process continues handling requests.

**⚠️ Warning:** This is powerful and dangerous. You're running arbitrary code in production. Use with extreme caution.

### 🎯 When to Use rbtrace

Use rbtrace when:
- Stack traces show WHERE the problem is, but you need to see variable VALUES
- You need to inspect live state (current request parameters, session data, connection pool)
- You want to trace method calls in real-time (see every invocation with arguments)
- Signal handlers would require too much code / too many deploys to iterate

**Advantage:** Full Ruby introspection without redeployment. You can run any Ruby code you want.

### Prerequisites

**Gem installation:**

```ruby
# Add to Gemfile
gem 'rbtrace'

# bundle install and redeploy
```

**Runtime setup:**

```ruby
# config/puma.rb or config/boot.rb
require 'rbtrace' if ENV['ENABLE_RBTRACE'] == 'true'
```

### Basic Usage

```bash
# Attach to process
rbtrace -p <PID>

# Execute Ruby code
rbtrace -p <PID> -e 'puts Thread.list.size'

# Trace method calls
rbtrace -p <PID> -m User#authenticate
```

### 🛡️ Production Safety

**Invasiveness:** High (injects and executes code)  
**Overhead:** Depends on injected code (can be negligible or catastrophic)  
**Risks:** Can crash process, corrupt state, or hang indefinitely  

**Safe practices:**
- Test injection code in staging first
- Keep injected code simple (1-5 lines)
- Always wrap in begin/rescue
- Have rollback plan (restart pod)

### ⏭️ When to Escalate to Level 6

Move to gdb when:
- Problem is in C extensions (Nokogiri, JSON gem, database drivers)
- You suspect memory corruption
- Ruby process segfaults
- rbtrace can't attach

**Level 5 Key Takeaways:**
- ✅ When to use: Variable inspection, live state debugging, method tracing
- ⚡ Impact: Depends on injected code; can crash process
- 📊 Info gained: Anything you can express in Ruby code; full introspection
- ⏭️ Escalate when: Problem is in C extension, memory corruption, or segfaults

## Level 6: System-Level Debugging 🚨

### What is gdb?

gdb (GNU Debugger) is a system-level debugger that operates at the C level. When debugging Ruby with gdb, you're inspecting the Ruby VM itself: C structs, memory addresses, stack frames at the machine level.

This is the deepest you can go. You're no longer in Ruby-land—you're in the C implementation of Ruby (CRuby/MRI).

**⚠️ DANGER:** gdb can CRASH YOUR PROCESS with incorrect commands. This is truly a last resort.

### 🎯 When to Use gdb

Use gdb when:
- Your Ruby process segfaults (signal 11)
- You suspect memory corruption in C extensions
- Need to inspect Ruby internals (object layout, GC state)
- Problem is in native gems (pg, nokogiri, json)
- All higher-level tools have failed

**Only use gdb if you understand C and Ruby's C internals.**

### Prerequisites

```bash
# Linux
apt-get install gdb ruby-debug

# macOS
brew install gdb
```

### Basic Usage

```bash
# Attach (this PAUSES the process!)
gdb -p <PID>

# Basic commands
(gdb) bt             # Backtrace (C stack trace)
(gdb) info threads   # List all threads
(gdb) detach         # IMPORTANT: Detach and resume
(gdb) quit
```

### 🛡️ Production Safety

**Invasiveness:** Very High (pauses process, inspects memory)  
**Overhead:** Process is STOPPED while attached  
**Risks:** Can crash process, corrupt memory, leave in inconsistent state  

**Risks:**
- **Pauses process:** ALL requests stop while gdb is attached
- **Can crash:** Wrong command can kill the process
- **No undo:** Once you modify memory, there's no rollback

### 🆘 When You've Reached the End

If Level 6 doesn't solve your problem:

1. **Collect artifacts:** Core dump, heap dump, logs, profiler data
2. **Restart the process:** You've exhausted debugging options
3. **Post-incident analysis:** Review with team, file bug reports

**Level 6 Key Takeaways:**
- ✅ When to use: Segfaults, C extension bugs, memory corruption, last resort
- ⚡ Impact: Process STOPS while attached; can crash
- 📊 Info gained: C-level stack traces, memory inspection, VM internals
- ⏭️ Escalate when: Restart and collect artifacts for post-mortem

## Decision Matrix: Quick Reference 📊

### Symptom → Tool Mapping

| Symptom | Recommended Starting Level | Why |
|---------|---------------------------|-----|
| Slow API responses (high CPU) | Level 1 (rbspy) | CPU profiling pinpoints hot methods |
| Slow API responses (low CPU) | Level 3 (signals) | I/O or blocking, not CPU |
| Memory leak | Level 1 (rbspy) + Level 6 (gdb heap dump) | Profile to find allocations |
| Hanging requests | Level 3 (signals) | Stack traces show where stuck |
| Deadlock | Level 3 (signals) | Stack traces show lock contention |
| CPU spike | Level 1 (rbspy) | Profiling identifies cause |
| Segfault | Level 6 (gdb) | System-level debugging required |

### Tool Comparison Matrix

| Level | Tool | Invasiveness | Can Crash? | Overhead | Best For |
|-------|------|--------------|------------|----------|----------|
| 1 | rbspy | Low | No | <1% CPU | CPU usage, first-pass profiling |
| 2 | kubectl debug | Low | No | Sidecar resources | Installing tools, file inspection |
| 3 | kill signals | Medium | Rarely | None | Quick diagnosis, deadlock detection |
| 4 | puma handlers | Medium | Rarely | Depends | Connection pools, job queues |
| 5 | rbtrace | High | Yes | Depends | Variable inspection |
| 6 | gdb | Very High | Yes | Process stops | Segfaults, memory corruption |

## Real-World Pattern: Memory Leak Investigation

**Scenario:** API pod memory grows from 500MB to 3GB over 8 hours, then OOMs.

**Phase 1: Confirm it's a leak (Level 1)**

Profile leaking pod vs healthy pod with rbspy:

```bash
kubectl exec api-pod-leaky -- rbspy record --pid $(pgrep ruby) --duration 120 --file /tmp/profile.svg
kubectl cp api-pod-leaky:/tmp/profile.svg ./leaky-profile.svg
```

**Findings:** Leaky pod spends 60% time in `ImageProcessor#resize` (vs 15% in healthy pod).

**Phase 2: Identify what's leaking (Level 5)**

Use rbtrace to check ObjectSpace:

```bash
kubectl exec -it api-pod-leaky -- rbtrace -p $(pgrep ruby) -e '
  require "objspace"
  counts = Hash.new(0)
  ObjectSpace.each_object(String) do |str|
    counts[str.size] += 1 if str.size > 1000000
  end
  puts "Large strings: #{counts.size}"
'
```

**Findings:** 234 large strings (~5MB each), likely image data.

**Phase 3: Find root cause**

Check code and find `ImageCache` class with unbounded `@cache` class variable.

**Resolution:** Replace with Rails.cache with TTL or LRU cache.

**Tools used:** rbspy → rbtrace → code fix (progressive escalation)

## Conclusion & Best Practices ✨

### Key Takeaways

**The Progressive Escalation Principle:**
- Start with the safest tool (rbspy)
- Escalate only when necessary
- Know when to stop and restart

**The Six Levels at a Glance:**
1. **rbspy**: Your first line of defense - safe, fast, informative
2. **kubectl debug**: When you need tools not in your container
3. **kill signals**: Quick stack traces for blocking issues
4. **puma handlers**: Custom diagnostics tailored to your app
5. **rbtrace**: Live variable inspection when you need it
6. **gdb**: Last resort for crashes and memory corruption

### Building Your Debugging Toolkit

**For your team:**

1. **Enable rbspy in production images** (Level 1)
   ```dockerfile
   RUN wget https://github.com/rbspy/rbspy/releases/download/v0.12.0/rbspy-x86_64-unknown-linux-musl.tar.gz \
       && tar xf rbspy*.tar.gz \
       && mv rbspy /usr/local/bin/
   ```

2. **Add custom signal handlers** (Level 4)
3. **Create debugging runbook** linking to this guide
4. **Set up monitoring** to detect issues early

### Further Reading

**Tools:**
- [rbspy documentation](https://rbspy.github.io/)
- [kubectl debug guide](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/)
- [rbtrace GitHub](https://github.com/tmm1/rbtrace)

**Ruby internals:**
- [Ruby Under a Microscope](http://patshaughnessy.net/ruby-under-a-microscope)
- [Ruby Hacking Guide](https://ruby-hacking-guide.github.io/)

---

## Final Thoughts

Production debugging is part science, part art. The tools in this guide give you the science—the systematic approach to uncovering issues. The art comes from experience: knowing which tool to reach for, reading between the lines of stack traces, and developing intuition for what "normal" looks like in your application.

**Remember these principles:**
- Debuggability is a feature, not an afterthought
- Observability prevents debugging
- The best debugging session is the one you don't need

Stay curious. Stay safe. And may your production deployments be ever stable.

**Happy debugging!** 🎯
