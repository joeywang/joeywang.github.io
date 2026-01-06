---
layout: post
title: "Rails Style Guide: Transactions, Touch, and Async Derived Data"
date: 2025-12-21
draft: false
categories:
  - rails
  - style-guide
  - best-practices
tags:
  - rails
  - style-guide
  - best-practices
---

# Rails Style Guide

## Transactions, Touch, and Async Derived Data

This document defines **official patterns and anti-patterns** for handling transactions, derived data, `touch`, and async updates in Rails services at Reallyenglish.

The goal is to keep the system:

* **Correct** (core data is always valid)
* **Performant** (writes stay fast, reads stay cheap)
* **Scalable** (bursts and retries do not break invariants)

---

## 1. Data Classification (Mandatory Mental Model)

All data MUST be classified before implementation.

| Category     | Examples                                | Consistency Requirement |
| ------------ | --------------------------------------- | ----------------------- |
| Core data    | domain truth, state machines, ownership | Strong (transactional)  |
| Derived data | counters, summaries, rollups            | Eventual                |
| Cache        | fragments, JSON blobs                   | Best-effort             |
| Analytics    | reports, metrics                        | Rebuildable             |

**Rule:** Only core data belongs inside transactions.

---

## 2. Transactions: What Is Allowed

### ✅ Allowed inside transactions

* Creating/updating core records
* Enforcing invariants
* Validations that affect correctness

### ❌ Forbidden inside transactions

* Aggregate queries (`count`, `sum`, `exists?` on associations)
* Cache updates
* Summary updates
* Enqueuing async jobs (unless after_commit)

### Approved pattern

```rb
ActiveRecord::Base.transaction do
  address.update!(params)
end
```

---

## 3. Timeline Diagram: Transaction vs Async

### ❌ Bad (Derived work inside transaction)

```
Request
  │
  ├─ BEGIN TRANSACTION
  │    ├─ write core row
  │    ├─ scan associations (slow)
  │    ├─ update summary columns
  │    └─ lock contention grows
  │
  └─ COMMIT
```

Problems:

* Long locks
* Deadlocks
* Slow user-facing writes

---

### ✅ Good (Core write + async)

```
Request
  │
  ├─ BEGIN TRANSACTION
  │    └─ write core row
  │
  ├─ COMMIT
  │
  └─ after_commit
       └─ enqueue async rollup

Background Worker
  └─ rebuild derived data
```

Benefits:

* Short transactions
* Retry-safe work
* Predictable performance

---

## 4. `touch`: Official Usage

### What `touch` IS

* A **change signal**
* A cache invalidation mechanism
* A dependency tracker

### What `touch` IS NOT

* A summary calculator
* A counter updater
* A guarantee of correctness

### Approved usage

```rb
class Address < ApplicationRecord
  belongs_to :student, touch: true
end
```

Use `touch` to answer:

> "Has anything under this record changed since I last looked?"

---

## 5. Derived Data Strategies (Choose One Explicitly)

### Strategy A — Delta-based updates

**Use when:**

* Append-only data
* Clear +1 / -1 semantics

```rb
after_commit do
  Student.update_counters(student_id, addresses_count: 1)
end
```

**Pros:** Fast reads, cheap writes
**Cons:** Drift risk, retry sensitivity

---

### Strategy B — Full recompute

**Use when:**

* Records can be edited or deleted
* Logic is conditional or complex

```rb
after_commit do
  StudentRollupJob.perform_later(student_id)
end
```

**Pros:** Correct, idempotent
**Cons:** More expensive

---

### Strategy C — Dirty flag (recommended default)

```rb
# students.needs_address_rollup :boolean

Student.where(id: student_id)
       .update_all(needs_address_rollup: true)
```

A worker periodically rebuilds flagged rows.

**Pros:** Burst-safe, scalable
**Cons:** Slight staleness

---

### Strategy D — Versioned touch (advanced, preferred for async)

```rb
# students.addresses_version :integer

Student.where(id: student_id)
       .update_all("addresses_version = addresses_version + 1")
```

Jobs validate versions before writing.

**Pros:** Async-safe, cache-friendly
**Cons:** More complex

---

## 6. Async Job Rules (Non-Negotiable)

All async jobs MUST be:

* Idempotent **or** discardable
* Safe to retry
* Safe to run out of order

### ❌ Forbidden

```rb
# blindly overwriting
student.update!(addresses_count: value)
```

### ✅ Approved

```rb
return if student.addresses_version > version_seen
```

---

## 7. Performance Rules

### Avoid

* Touching parent rows in tight loops
* One job per child update
* Synchronous recomputation

### Prefer

* Debouncing
* Deduped jobs by parent ID
* Periodic reconciliation

---

## 8. Reconciliation (Required)

Every derived column MUST have a reconciliation path.

```rb
Student.find_each do |student|
  actual = student.addresses.count
  next if actual == student.addresses_count

  student.update!(addresses_count: actual)
end
```

Reconciliation enables:

* Aggressive optimization
* Drift detection
* Confidence in async design

---

## 9. Decision Checklist (Required Before Merge)

Before adding derived data, answer:

* Can this be rebuilt?
* Can it be stale for seconds/minutes?
* Can jobs retry or reorder?
* Can updates happen in bursts?

If **yes** to any → do NOT compute inside a transaction.

---

## 10. Final Principle

> Transactions protect truth.
> Everything else is a snapshot.

Following this guide is mandatory for all new Rails code touching derived data.
