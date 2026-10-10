---
layout: post
title: "Sidekiq Queue Strategies: Match Urgency and Tolerance to the Job"
date: 2026-09-27 19:00:00 +0000
author: "Joey Wang"
description: "A practical way to classify Sidekiq jobs by urgency, failure tolerance, duplication risk, and queue strategy."
tags: [ruby, rails, sidekiq, background-jobs, reliability]
categories: [Engineering]
---

<div class="audio-summary">
  <p><strong>Audio summary:</strong> a short spoken version of this post.</p>
  <audio controls preload="metadata">
    <source src="/assets/audio/2026-09-27-sidekiq-queue-strategies-summary.ogg" type="audio/ogg">
    Your browser does not support the audio element.
  </audio>
</div>

A Sidekiq queue called `default` is easy to start with. It is also an easy place to hide a growing set of contradictory requirements.

An email, a payment reconciliation, a search-index refresh, a nightly report, and a cache warm-up can all be valid background jobs. They do not have the same urgency. They do not have the same tolerance for delay. They do not have the same answer to the question: "What happens if this job is enqueued twice?"

The queue name is not the strategy. It is only the first label.

The useful design work is to classify each job before deciding where it runs:

```text
urgency       How quickly does it need to start?
tolerance     How bad is a delay or a missed run?
duplicates    Is a second copy harmless, wasteful, or dangerous?
retry         Should failure wait, retry, or alert somebody?
concurrency   Can several copies run safely at the same time?
```

Once those answers are written down, Sidekiq's queue modes and uniqueness options become much easier to use without turning `sidekiq.yml` into a collection of guesses.

## Start with urgency and tolerance

I find it useful to separate two properties that are often treated as one.

**Urgency** is about time to start. A job may be urgent because a user is waiting for its result, or because a delayed action will make another workflow incorrect.

**Tolerance** is about how much delay or loss the business can accept. A low-urgency job may still have low tolerance for being lost. A nightly export can wait for an hour, but it may still need an operator-visible failure if it has not completed by morning.

That gives a rough first classification:

| Class | Urgency | Delay tolerance | Typical jobs |
| --- | --- | --- | --- |
| Critical | high | low | payment capture, access changes, time-sensitive notifications |
| Interactive | high | short | user-requested exports, document generation, webhook follow-up |
| Important | medium | moderate | search indexing, CRM sync, progress aggregation |
| Bulk | low | high | historical backfills, analytics imports, cache warming |
| Periodic | deadline-based | depends on deadline | daily reports, cleanup, reconciliation |

This is not a universal taxonomy. It is a prompt to make the trade-off visible.

A job's class should also answer what happens when the system is busy. If bulk work consumes every thread, should an access-change job wait behind it? If the answer is no, the queues need separate capacity, not only different names.

## One queue is a policy decision

A single queue is not neutral. It says that all jobs compete for the same capacity and that the order in which they are checked is good enough.

That may be perfectly reasonable for a small application. It becomes a problem when a slow or high-volume producer can delay a different kind of work.

A simple separation might look like this:

```text
critical   payments, security, account changes
interactive user-facing work with a short response expectation
normal     ordinary application jobs
bulk       imports, backfills, expensive maintenance
```

The names are less important than the ownership rules. A queue should have a reason to exist, a rough workload profile, and a way to tell whether it is being starved.

Sidekiq supports strict queue ordering and weighted queues. Strict ordering means a process checks queues in the declared order. Weighted queues give a queue more chances to be selected, but they do not guarantee a fixed percentage of completed work. The [Sidekiq advanced options](https://sidekiq.org/wiki/Advanced-Options) documentation describes both modes and the limitation that a process cannot mix them.

For example, a weighted process could be configured like this:

```yaml
:queues:
  - [critical, 6]
  - [interactive, 3]
  - [normal, 2]
  - [bulk, 1]
```

This is a useful starting point when the queues share a worker pool and the application can tolerate probabilistic selection. It is not a service-level agreement. A busy `critical` queue can still consume capacity, and a low-weight queue can still wait for a long time under sustained load.

## When separate processes are clearer

If a queue must remain available even when another workload is unhealthy, give it separate process capacity.

For example:

```text
process A: critical, interactive
process B: normal
process C: bulk
```

Or, if critical work really must be checked first within its process:

```text
process A: critical -> interactive
process B: normal -> bulk
```

This costs more operationally, but it makes the boundary easier to reason about. A large import cannot fill every worker slot needed for a payment-related job.

Strict ordering has a catch: lower queues can starve while higher queues remain busy. Weighted queues have a different catch: they improve sharing but do not provide a hard deadline. The choice depends on which failure is worse for the application.

I would rather have two deliberately sized processes than six queues that all run through one overloaded pool with no clear capacity model.

## Make the job itself safe to retry

Queue selection cannot repair a job that is unsafe to run twice.

Sidekiq retries failed jobs, and a worker can lose its connection after the remote operation has succeeded but before the process records success locally. From the application's point of view, the job may be attempted again even though the first attempt partially completed.

That is why idempotency belongs in the job design, not only in the queue configuration.

A job that records a payment, sends a message, or applies an external change should have a business-level idempotency key where the downstream system supports one. A job that updates a local projection should usually write the same result again safely rather than assuming it will run exactly once.

```ruby
class RebuildSearchDocumentJob
  include Sidekiq::Job

  sidekiq_options queue: :normal, retry: 8

  def perform(document_id)
    document = Document.find(document_id)
    SearchIndex.upsert(document.id, document.search_payload)
  end
end
```

The important property here is not the number `8`. It is that `upsert` and the document payload make a retry safe. Retry counts should follow the failure mode and the business deadline, not a copied default.

## Uniqueness is not idempotency

A uniqueness lock answers a different question:

> Should I allow another copy of this job to be enqueued or executed while this copy is in progress?

Idempotency answers:

> If this operation happens again, will the result remain correct?

A unique lock can reduce duplicate work. It cannot prove that a remote API call happened only once, and it cannot replace a durable business record or an idempotency key.

There are two common ways to get uniqueness in Sidekiq applications:

- Sidekiq Enterprise's built-in unique jobs feature;
- the open source [`sidekiq-unique-jobs`](https://github.com/mhenrixon/sidekiq-unique-jobs) gem.

They have different APIs and operational details, so a team should choose one deliberately and read the version-specific documentation. The examples below use `sidekiq-unique-jobs` terminology.

## Choose the lock from the duplicate failure mode

The gem provides several lock types. The useful question is not "Which lock is strongest?" It is "At what point do duplicates become a problem?"

### Duplicate enqueueing is wasteful

Suppose a record is edited several times in a short period and each edit queues a search refresh. The latest refresh may make earlier refreshes unnecessary.

```ruby
class RefreshSearchJob
  include Sidekiq::Job

  sidekiq_options \
    queue: :normal,
    lock: :until_executing,
    on_conflict: :log

  def perform(record_id)
    SearchIndex.refresh(record_id)
  end
end
```

An `:until_executing` lock prevents multiple copies from accumulating before the worker starts. This is appropriate when dropping a duplicate is acceptable because another job will produce the same current state.

It is not appropriate for a job where every event must be processed. In that case, model the event or use an outbox rather than treating a duplicate as disposable.

### The whole operation should remain unique

For a rebuild or synchronization that should not overlap with another copy, `:until_executed` holds the lock through execution:

```ruby
class SyncCustomerJob
  include Sidekiq::Job

  sidekiq_options \
    queue: :important,
    lock: :until_executed,
    on_conflict: :log,
    retry: 6

  def perform(customer_id)
    CustomerSync.call(customer_id)
  end
end
```

This can stop a thundering herd when several triggers request the same synchronization. It also means that a failed job may keep the lock while it retries, depending on the lock and retry behavior. That can be correct, but it can also delay a fresh request longer than the caller expects.

### Only concurrent execution is unsafe

Some jobs are safe to enqueue more than once but unsafe to run concurrently. A generated report might be overwritten by two writers, or a third-party endpoint might reject simultaneous updates.

For that case, `:while_executing` is a server-side concurrency lock. It does not stop duplicate jobs from entering Redis. It stops them from doing the protected work at the same time.

That distinction matters operationally. A queue can still grow even when only one copy is executing.

### A time window matters more than the exact job

For periodic work, `:until_expired` can be useful when the business rule is "at most one request per interval" rather than "one copy until successful completion".

Be careful with long lock periods. A lock can prevent a legitimate recovery or manual rerun. Locks also need an expiry or a cleanup plan, because a process can die while a lock exists.

The Sidekiq Enterprise documentation makes the same broader point about uniqueness: treat it as best effort, use a bounded period, and keep the lock short. The open source gem has its own reaper and configuration choices, but the operational lesson is the same.

## Conflict strategy is part of the business rule

When a duplicate is detected, the result should be intentional:

- `:log` is reasonable when the duplicate is harmless and should be discarded.
- `:reject` is useful when an operator needs a visible record that a required job was not accepted.
- `:reschedule` can be appropriate when the work must happen later, but it changes queue pressure and retry statistics.
- `:replace` fits jobs where the newest request supersedes an older pending request.

The correct choice depends on whether the duplicate represents the same desired state or a separate event.

For example, two requests to rebuild the current search document may collapse into one. Two invoice events should not. The first is state convergence; the second is event processing. Giving both jobs the same uniqueness policy is a data-model mistake disguised as a queue setting.

## A practical classification table

Before adding a new worker, I would write a small record like this:

| Question | Example answer for a search refresh |
| --- | --- |
| User waiting? | No |
| Start within | A few minutes |
| Maximum useful delay | 30 minutes |
| Duplicate meaning | Same desired state |
| Concurrent execution safe? | Yes, if the index uses upsert |
| Retry | Yes, with bounded backoff |
| Queue | `normal` |
| Uniqueness | `:until_executing` |
| Conflict | Log and drop |
| Alert | Queue age or repeated failures |

For a payment capture, the answers would be different. The job might need a dedicated high-priority process, a durable idempotency key, an explicit failure alert, and no silent duplicate dropping.

Writing the answers down also exposes missing requirements. If nobody knows the maximum useful delay, it is difficult to choose a queue weight responsibly.

## Watch the queue, not just the worker

A healthy Sidekiq process can still be serving an unhealthy queue policy. I would monitor at least:

- queue latency by queue;
- oldest job age;
- retry and dead-set growth;
- execution time and failure rate by worker;
- duplicate conflicts and lock cleanup;
- concurrency saturation;
- the number of jobs enqueued versus completed.

Queue latency is often more useful than total job count. A bulk queue can contain many jobs without being in trouble. A critical queue with a small number of old jobs may already be failing its purpose.

Alerts should follow the class of work. A five-minute delay may be harmless for a backfill and unacceptable for an access change. One global queue-latency threshold usually hides that distinction.

## The strategy I would use first

For a Rails application with mixed workloads, I would start conservatively:

1. Keep the default queue for ordinary work only.
2. Create a separate `critical` or `interactive` queue only when there is a measured reason.
3. Move bulk work away from the process that serves user-facing jobs.
4. Make every retrying job idempotent at the business boundary.
5. Add uniqueness only where duplicate work is a known problem.
6. Choose the conflict behavior explicitly rather than accepting a silent default.
7. Monitor queue age by class before tuning weights.
8. Revisit the classification when the workload or deadline changes.

The goal is not to produce a complicated queue topology. It is to stop unrelated jobs from competing as if they had the same urgency and the same failure semantics.

Sidekiq gives us useful mechanics: queues, weights, retries, capsules, and uniqueness locks. The application still has to decide what a job means, how late is too late, and whether a duplicate is an error, a no-op, or a separate event. Those decisions belong in the design of the job, not hidden in a YAML file.

## References

- [Sidekiq advanced queue options](https://sidekiq.org/wiki/Advanced-Options)
- [Sidekiq reliability and queue prioritisation](https://sidekiq.org/wiki/Reliability)
- [Sidekiq Enterprise unique jobs](https://sidekiq.org/wiki/Ent-Unique-Jobs)
- [`sidekiq-unique-jobs` documentation](https://github.com/mhenrixon/sidekiq-unique-jobs)
