---
layout: post
title: "Transactions, touch, and async rollups for derived data in Rails"
description: "Keeping counters and summaries accurate in Rails without slowing down writes means separating core data in a transaction from derived data updated after commit."
date: 2025-12-20
tags: [rails, database, architecture, performance]
---

<audio controls preload="metadata" src="/assets/audio/transactions-touches-async-summary.ogg">
  Your browser does not support the audio element.
</audio>

In real-world Rails applications, not all data is equal. Some columns are core truth: the values your business logic actually depends on. Others exist for convenience, performance, or observability: counters, summaries, snapshots, caches. The problem is keeping those derived fields accurate without slowing down writes or introducing correctness bugs, especially once async jobs and transactions are both in the picture.

## The core problem

```text
Student has_many Addresses
Student has summary fields derived from Addresses
```

Examples of derived data: `addresses_count`, `has_verified_address`, `latest_country`, `address_summary_json`, `addresses_updated_at`. Whenever an `Address` changes, the `Student` should reflect that, but you don't want to scan every address on each read, recompute expensive summaries on every write, or let a retried or rolled-back job corrupt the count. That's a consistency-versus-performance problem, not just a syntax question.

## Separate core writes from derived writes

The core principle: only write core data inside the transaction. Derived data gets updated after commit. Transactions can roll back, jobs can retry, and a side effect like a counter or cache should never reflect data that never actually landed.

Anti-pattern:

```rb
ActiveRecord::Base.transaction do
  address.update!(...)
  student.update!(addresses_count: student.addresses.count)
end
```

If this transaction retries, deadlocks, or partially fails, you get incorrect counters, expensive queries held inside a lock, and contention you didn't need.

## Rails touch: a lightweight change signal

```rb
class Address < ApplicationRecord
  belongs_to :student, touch: true
end
```

`touch` gives you a cheap, automatic "something under me changed" signal without scanning associations to detect it, which plays well with HTTP caching, fragment caching, and snapshots. It's good for cache invalidation, change detection, and dependency tracking. It is not a summary calculator, a counter manager, or a guarantee that derived data is correct. Treat it as a notification, not a computation.

## Strategy 1: delta-based updates

Apply a small delta on each change instead of recomputing:

```rb
class Address < ApplicationRecord
  belongs_to :student

  after_commit :increment_counter, on: :create
  after_commit :decrement_counter, on: :destroy

  def increment_counter
    Student.update_counters(student_id, addresses_count: 1)
  end

  def decrement_counter
    Student.update_counters(student_id, addresses_count: -1)
  end
end
```

Fast reads, no full-table scans, atomic SQL updates. The cost: updates are awkward (what happens when an address becomes invalid rather than created or destroyed?), retries can double-count without careful idempotency, and drift accumulates over time. Good fit for append-only data, simple counts, and hot read paths, provided you also run reconciliation.

## Strategy 2: recompute on change

Every meaningful change triggers a full rebuild:

```rb
class Address < ApplicationRecord
  belongs_to :student

  after_commit :enqueue_rollup

  def enqueue_rollup
    StudentAddressRollupJob.perform_later(student_id)
  end
end

class StudentAddressRollupJob < ApplicationJob
  def perform(student_id)
    student = Student.find(student_id)

    student.update!(
      addresses_count: student.addresses.count,
      has_verified_address: student.addresses.verified.exists?
    )
  end
end
```

Naturally idempotent, safe with retries, handles edits and deletes without special-casing. It costs more per update and can spam jobs under bursty writes unless you throttle or dedupe. Use it when the derived logic is complex, edits can change prior state, and correctness matters more than write cost.

## Strategy 3: touch plus a dirty flag

Separate change detection from the work itself. Mark the parent dirty on every child change:

```rb
# students.needs_address_rollup :boolean

class Address < ApplicationRecord
  belongs_to :student

  after_commit :mark_student_dirty

  def mark_student_dirty
    Student.where(id: student_id)
           .update_all(needs_address_rollup: true, updated_at: Time.current)
  end
end
```

A worker then processes only dirty students on its own schedule:

```rb
Student.where(needs_address_rollup: true).find_each do |student|
  rebuild_address_summary(student)
  student.update!(needs_address_rollup: false)
end
```

This coalesces bursts of updates into one rebuild instead of one job per change, at the cost of some staleness and an extra background sweeper. It scales well precisely because it decouples "something changed" from "do the work now."

## Strategy 4: versioned touch

Instead of "something changed," track how many times it changed:

```rb
# students.addresses_version :integer

class Address < ApplicationRecord
  after_commit do
    Student.where(id: student_id)
           .update_all("addresses_version = addresses_version + 1")
  end
end
```

Cache keys can include `addresses_version`, and jobs can carry the version they observed so a stale, out-of-order job safely no-ops instead of overwriting newer data:

```rb
def perform(student_id, version)
  student = Student.find(student_id)
  return if student.addresses_version > version

  rebuild_summary(student)
end
```

More moving parts than a plain dirty flag, but it's the strategy that actually prevents stale writes under concurrent, out-of-order job execution, which makes it a good default for anything cache-adjacent running async.

## Performance considerations

`touch` updates the parent row on every child write, and under frequent child updates that becomes row-lock contention and replication lag. Debouncing, batching imports, and preferring a dirty flag or version counter over raw `touch` all reduce that. On the job side, one job per child update doesn't scale; dedupe by parent ID and let bursts collapse into a single run. Whatever strategy you pick, keep a periodic full rebuild job around: it fixes drift, catches bugs in the incremental path early, and gives you the confidence to optimize the hot path aggressively.

| Use case | Recommended strategy |
| --- | --- |
| Simple counter | Delta or counter_cache |
| Editable or deletable rows | Recompute |
| Cache invalidation | touch |
| Burst-heavy writes | Dirty flag |
| Async correctness | Versioned touch |
| High-read system | Hybrid |

Derived data is never free. You pay for it at write time with synchronous updates, at read time with scans, or in complexity with async processing and reconciliation. Rails gives you the primitives, transactions, `after_commit`, `touch`, but which of these strategies you pick is the architecture decision that actually matters. Keep transactions small, treat derived data as rebuildable, and reconcile periodically, and the system stays both fast and correct as it grows.
