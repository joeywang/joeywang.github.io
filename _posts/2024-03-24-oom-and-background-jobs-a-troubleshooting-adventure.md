---
layout: post
title: "When the OOM Killer Silently Kills a Background Job"
description: "A missed notification email traced back to the Linux OOM killer terminating a Sidekiq job mid-run, leaving a stuck Redis lock and no error logged anywhere."
date: 2024-03-24 00:00 +0000
categories: [DevOps]
tags: [kubernetes, linux, debugging, sidekiq]
---
<audio controls preload="metadata" src="/assets/audio/oom-and-background-jobs-a-troubleshooting-adventure-summary.ogg">
  Your browser does not support the audio element.
</audio>


A customer's notification email didn't arrive on time. When I went looking for why, every log was empty: nothing in Sentry, nothing in the Sidekiq logs, nothing in the job queue history. Whatever ran that job didn't get the chance to log an error before it died.

I'd seen this before: a Sidekiq job killed mid-run by the OOM killer, leaving a Redis lock stuck with no trace of what happened. That was the culprit again.

## What the OOM killer actually does

Out of memory means a process, container, or the whole system is asking for more memory than is available. On Linux, the kernel's response is the OOM killer: when memory is critically low, it picks a process and kills it to free memory immediately. It doesn't warn the process first and it doesn't give it a chance to flush logs.

The kernel scores every process with an `oom_score`. Higher score, more likely to be picked when memory runs out. The score factors in:

- **RSS** (resident set size): non-swapped physical memory the process is using.
- **PSS** (proportional set size): its share of memory shared with other processes.
- Kernel thread count at the same priority.
- Whether the process runs in user space (more likely to be killed) or kernel space.
- `oom_score_adj`, a tunable per-process bias; a lower value makes a process less likely to be picked.

In Kubernetes, the kubelet doesn't kill anything itself. It watches each container's memory against its configured limit, and when a container goes over, it asks the host kernel's OOM killer to act. The container just stops, with no distinction in the pod's logs between "crashed" and "was killed for memory."

## Finding the evidence after the fact

None of the application-level logs show an OOM kill, because the process is dead before it can write anything. What does show it:

- `dmesg`, the kernel's ring buffer, usually has the kill logged.
- `/var/log/kern.log`, on systems that keep one, persists the same information.
- `/proc/<pid>/oom_score` shows a live process's current score.
- `/proc/<pid>/oom_score_adj` lets you bias a process away from being picked.

If a job runner or Sidekiq worker vanishes with no error, check `dmesg` for "Out of memory: Killed process" before looking anywhere else.

## What actually reduces OOM kills

- Monitor memory per container, not just per node; one noisy pod can trigger a kill that looks like a node-wide problem.
- Set memory limits that match real usage, not a guess. A limit that's too tight turns normal load spikes into OOM kills.
- Find and fix leaks and oversized data structures in the job itself; an OOM kill is a symptom of memory consumption, not a bug in Kubernetes.
- Cache with a bound. An unbounded in-process cache is a slow-motion OOM.
- Scale horizontally so no single pod holds all the memory-heavy work.
- Use Kubernetes QoS classes (`Guaranteed`, `Burstable`, `BestEffort`) so critical workloads aren't first in line when a node runs low.

The lesson from this incident specifically: if a background job holds a lock and gets OOM-killed, that lock does not get released. Whatever acquires the lock needs a TTL or a watchdog independent of the job's own cleanup code, because an OOM kill skips `ensure` blocks entirely.
