---
layout: post
title: "Transactions, Touches, and Async Rollups in Ruby on Rails"
date: 2025-12-20
tags: [ruby-on-rails, database, architecture, async-jobs, data-consistency]
---

# Transactions, Touches, and Async Rollups in Ruby on Rails

### Designing Consistent, Performant Derived Data

In real-world Rails applications, not all data is equal.

Some columns represent **core truth** — the values your business logic fundamentally depends on.
Others exist for **convenience, performance, or observability** — counters, summaries, snapshots, and caches.

The challenge is keeping these *derived* fields accurate **without slowing down writes or creating correctness bugs**, especially when async jobs and transactions are involved.

This article explores:

* Why naïve approaches fail
* How Rails’ `touch` pattern fits into the picture
* Multiple strategies for derived data
* Trade-offs between sync vs async updates
* Practical patterns that scale

---

## 1. The Core Problem

Consider a common example:

```text
Student has_many Addresses
Student has summary fields derived from Addresses
```

Examples of derived data:

* `addresses_count`
* `has_verified_address`
* `latest_country`
* `address_summary_json`
* `addresses_updated_at`

Whenever an `Address` changes, the `Student` **should reflect that change**, but:

* We don’t want to scan all addresses on every read
* We don’t want to recompute expensive summaries on every write
* We don’t want async jobs to corrupt data due to retries or rollbacks

This is fundamentally a **data consistency vs performance** problem.

---

## 2. First Principle: Separate Core Writes from Derived Writes

A crucial design principle:

> **Only write core data inside the transaction.
> Derived data should be updated *after commit*.**

Why?

* Transactions can roll back
* Jobs can retry
* Side effects (stats, caches, summaries) should never reflect uncommitted data

### ❌ Anti-pattern

```rb
ActiveRecord::Base.transaction do
  address.update!(...)
  student.update!(addresses_count: student.addresses.count)
end
```

If this transaction retries, deadlocks, or partially fails, you risk:

* incorrect counters
* expensive queries inside locks
* unnecessary contention

---

## 3. Rails `touch`: A Lightweight Change Signal

Rails’ `touch` exists for a reason.

```rb
class Address < ApplicationRecord
  belongs_to :student, touch: true
end
```

This gives you:

* A cheap, automatic signal: *“something under me changed”*
* No need to scan associations to detect changes
* Natural compatibility with HTTP caching, fragment caching, and snapshots

### What `touch` is good at

* Cache invalidation
* Change detection
* Dependency tracking

### What `touch` is **not**

* A summary calculator
* A counter manager
* A guarantee that derived data is correct

Think of `touch` as **a notification, not a computation**.

---

## 4. Strategy 1: Increment / Decrement (Delta-Based Updates)

### Idea

When a change happens, apply a small delta:

```text
Address created  → +1
Address deleted  → -1
```

### Example

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

### Pros

✅ Very fast reads
✅ No full-table scans
✅ Atomic SQL updates

### Cons

❌ Hard to handle updates (what if an address becomes invalid?)
❌ Easy to double-count with job retries
❌ Requires idempotency discipline
❌ Drift accumulates over time

### When to use

* Append-only data
* Simple counts
* Extremely hot read paths
* You have reconciliation jobs

---

## 5. Strategy 2: Recompute on Change (Snapshot-Based)

### Idea

Every meaningful change triggers a rebuild:

```rb
class Address < ApplicationRecord
  belongs_to :student

  after_commit :enqueue_rollup

  def enqueue_rollup
    StudentAddressRollupJob.perform_later(student_id)
  end
end
```

```rb
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

### Pros

✅ Naturally idempotent
✅ Easy to reason about
✅ Safe with retries
✅ Handles edits, deletes, complex logic

### Cons

❌ More expensive
❌ Can spam jobs under burst updates
❌ Requires throttling or deduping

### When to use

* Complex derived logic
* Edits affect prior state
* Correctness > write performance
* Async processing is acceptable

---

## 6. Strategy 3: Touch + Dirty Flag (Debounced Rebuild)

This is where things get interesting.

### Idea

Separate **change detection** from **work execution**.

```rb
class Student < ApplicationRecord
  # needs_address_rollup :boolean
end
```

```rb
class Address < ApplicationRecord
  belongs_to :student

  after_commit :mark_student_dirty

  def mark_student_dirty
    Student.where(id: student_id)
           .update_all(needs_address_rollup: true, updated_at: Time.current)
  end
end
```

A worker periodically processes only dirty students:

```rb
Student.where(needs_address_rollup: true).find_each do |student|
  rebuild_address_summary(student)
  student.update!(needs_address_rollup: false)
end
```

### Pros

✅ Coalesces bursts of updates
✅ Avoids job spam
✅ Avoids repeated recomputes
✅ Still avoids scanning associations for detection

### Cons

❌ Slightly stale data
❌ Requires background sweeper
❌ More moving parts

This pattern scales *extremely well*.

---

## 7. Strategy 4: Versioned Touch (Modern & Powerful)

A more advanced evolution of `touch`.

### Idea

Instead of just “something changed”, track **how many times** it changed.

```rb
# students.addresses_version :integer
```

```rb
class Address < ApplicationRecord
  after_commit do
    Student.where(id: student_id)
           .update_all("addresses_version = addresses_version + 1")
  end
end
```

Now:

* Cache keys can include `addresses_version`
* Jobs can carry the version they observed
* Old jobs can safely no-op

```rb
def perform(student_id, version)
  student = Student.find(student_id)
  return if student.addresses_version > version

  rebuild_summary(student)
end
```

### Pros

✅ Excellent for async safety
✅ Prevents stale writes
✅ Ideal for caches & rollups
✅ Minimal locking

### Cons

❌ Slightly more complex mental model
❌ Requires discipline in usage

This pattern is **underused** and very effective.

---

## 8. Performance Considerations

### Write amplification

* `touch` updates parent rows
* Frequent child updates → row lock contention
* Replication lag on replicas

Mitigations:

* Debounce updates
* Batch imports
* Use dirty flags or versions instead of raw `touch`

### Async job storms

* One change → one job does not scale
* Prefer deduplication by `(student_id)`
* Delay execution slightly to collapse bursts

### Reconciliation

No matter the strategy:

> **Have a periodic full rebuild job**

It:

* Fixes drift
* Detects bugs early
* Lets you optimize aggressively elsewhere

---

## 9. A Practical Decision Matrix

| Use case                  | Recommended strategy   |
| ------------------------- | ---------------------- |
| Simple counter            | Delta or counter_cache |
| Editable / deletable rows | Recompute              |
| Cache invalidation        | touch                  |
| Burst-heavy writes        | Dirty flag             |
| Async correctness         | Versioned touch        |
| High-read system          | Hybrid                 |

---

## 10. Final Takeaway

Derived data is **not free** — you pay either:

* at write time (sync updates)
* at read time (scans)
* or in complexity (async + reconciliation)

Rails gives you powerful primitives (`transactions`, `after_commit`, `touch`), but **architecture choices matter more than syntax**.

The best systems:

* Keep transactions small
* Treat derived data as rebuildable
* Use async thoughtfully
* Accept eventual consistency where possible
* Reconcile periodically

If you design with those principles, your app will stay both **fast and correct** as it grows.
