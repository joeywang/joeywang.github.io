---
layout: post
title: "Understanding Deadlocks in MySQL and PostgreSQL: Integrity vs Performance"
date: "2025-01-01"
categories: database performance integrity
---

# Understanding Deadlocks in MySQL and PostgreSQL: Integrity vs Performance

## Introduction

Database deadlocks are a classic source of frustration for backend developers, especially when working with complex transactional workloads in systems like MySQL or PostgreSQL. A deadlock happens when two or more transactions are each waiting for the other to release a lock, and none can proceed. This article explores how deadlocks occur in MySQL and PostgreSQL, with examples, and dives into the heated debate between maintaining referential integrity via foreign keys versus sacrificing it for performance and scalability.

---

## What Is a Deadlock?

A deadlock occurs when:
- Transaction A holds a lock and waits for a lock held by Transaction B
- Transaction B is simultaneously waiting for a lock held by Transaction A

Since neither can proceed, the database intervenes and forcibly rolls back one of the transactions to break the cycle.

---

## Lock Types and Why They Matter

### Common Lock Types
- **Shared (S) Lock**: Allows concurrent reads but no writes. Used for foreign key checks.
- **Exclusive (X) Lock**: Blocks all other reads or writes. Required for updates/deletes.
- **Intention Locks**: Indicate the intention to acquire S or X locks at a lower level.
- **Gap Locks (MySQL only)**: Prevents inserts into a range of index values.
- **Insert Intention Locks (MySQL only)**: Special X lock for inserting into an index.

### How Shared Locks Can Still Deadlock
Shared locks by themselves are not harmful, but when combined with updates and insert intention locks, they can create dependency chains that lead to deadlocks. For example:

```sql
-- Transaction A
BEGIN;
UPDATE books SET genre_id = 1001 WHERE id = 1;

-- Transaction B
BEGIN;
UPDATE books SET genre_id = 1001 WHERE id = 2;
```

Both transactions take a shared lock on the `genres` table to validate the FK constraint, and then each tries to escalate to an exclusive lock to update the same index (`books.genre_id`). If the locking order differs, a deadlock may occur.

---

## Deadlocks in MySQL (InnoDB)

### Example Scenario
Imagine you're updating multiple `books` that share the same `genre_id`:

```sql
UPDATE books SET genre_id = 1001 WHERE id = 1;
UPDATE books SET genre_id = 1001 WHERE id = 2;
```

If two concurrent processes run these updates on different rows, but with the same foreign key (`genre_id`), InnoDB may:
- Lock the same **foreign key index**
- Use **gap locks** and **insert intention locks**
- Deadlock if the row/index locking order is different across transactions

### InnoDB Specifics
- Uses **gap locks** to prevent phantom reads
- Uses **insert intention locks** during updates that modify index values
- Deadlocks can occur even when rows being updated are different, due to index-level contention

---

## Deadlocks in PostgreSQL

PostgreSQL doesn't use gap locks, but still:
- Locks index entries during updates
- Uses **row-level locks** and **predicate locks**
- Applies **shared locks on parent rows** when using foreign keys

### Example Scenario
With a foreign key constraint like:
```sql
ALTER TABLE books ADD CONSTRAINT fk_genre FOREIGN KEY (genre_id) REFERENCES genres(id);
```
Updating books with the same `genre_id` will:
- Lock the `genres` row in shared mode
- Result in deadlocks if multiple transactions hold different locks and wait on each other

---

## Gap Insertion Intent: A Strategy for Reducing Lock Contention

Certain database operations, particularly those involving ordered data, can benefit from a pattern called "gap insertion intent." This strategy deliberately leaves spaces between sequential values (typically in numeric IDs or sort orders) to allow for easy future insertions without requiring extensive reordering or locking of existing data.

### How Gap Insertion Intent Works

Instead of assigning consecutive integers (1, 2, 3...) as sort positions or ordering values, you use larger increments (e.g., 1000, 2000, 3000) to leave significant gaps between values. This approach has several advantages:

1. **Reduced lock contention**: When inserting new records between existing ones, fewer rows need to be updated or locked
2. **Fewer deadlocks**: With fewer lock operations needed, deadlock probability decreases
3. **Better concurrency**: Multiple transactions can insert items in different gaps simultaneously

### Examples in Database Operations

#### Example 1: Task Ordering System

Consider a task management system where tasks have a specific display order:

```sql
-- Initial tasks with gap insertion intent
INSERT INTO tasks (id, title, sort_order) VALUES
(1, 'Research competitors', 1000),
(2, 'Create wireframes', 2000),
(3, 'Build prototype', 3000);
```

When a user needs to insert a task between existing ones:

```sql
-- Insert between tasks 1 and 2 without updating other rows
INSERT INTO tasks (id, title, sort_order) VALUES
(4, 'Review market analysis', 1500);
```

Without gap insertion intent, this operation would require updating multiple rows and potentially cause deadlocks in high-concurrency environments.

#### Example 2: Menu Organization

For a restaurant application with menu sections:

```sql
-- Initial menu items with gap insertion strategy
INSERT INTO menu_sections (id, name, display_order) VALUES
(1, 'Appetizers', 1000),
(2, 'Main Courses', 2000),
(3, 'Desserts', 3000);
```

Adding a new section becomes trivial:

```sql
-- Insert between sections without reordering
INSERT INTO menu_sections (id, name, display_order) VALUES
(4, 'Beverages', 2500);
```

### Implementation Approaches

1. **Fixed gap size**: Use consistent increments like 100, 1000, etc.
2. **Fractional strategy**: For inserting between positions A and B, use (A+B)/2
3. **Logarithmic spacing**: Use larger gaps at the beginning of the sequence

### When to Consider Rebalancing

Eventually, gaps between values may become too small (e.g., needing to insert between positions 1001 and 1002). At this point, a rebalancing operation can redistribute the values with new gaps:

```sql
-- Example rebalancing operation
UPDATE tasks
SET sort_order = sort_order * 1000
ORDER BY sort_order;
```

This operation temporarily increases lock contention but creates new gaps for future insertions.

---

## How to Mitigate Deadlocks

### General Strategies
- **Update rows in consistent order**: e.g., always by ascending `id`. If 8 processes each update distinct, non-overlapping ID ranges (e.g., 1–100, 101–200...), deadlocks are far less likely.
- **Process disjoint row ranges in parallel**
- **Batch updates** to reduce lock hold time
- **Avoid unnecessary FK constraints** in high-write workloads
- **Implement gap insertion intent** for ordering fields
- Use appropriate **transaction isolation levels**

### Foreign Key-Specific Strategies
- Avoid updating many rows that reference the same FK parent concurrently
- Defer FK checks if possible (`DEFERRABLE INITIALLY DEFERRED` in PostgreSQL)
- Consider removing FKs and handling integrity in application logic (with trade-offs)
- Ensure that FK value changes are **diverse** (not all to the same parent row), reducing contention

---

## The Trade-off: Integrity vs Performance

### Pros of Using Foreign Keys
- Built-in **referential integrity**
- **Cascading deletes/updates**
- Safer schema-level guarantees

### Cons in High-Concurrency Systems
- Increased **locking overhead**
- Harder to scale horizontally
- Can cause **deadlocks** and slower writes

### Why Some Teams Drop FKs
- Prefer **application-level integrity checks**
- Easier to scale distributed systems (especially with sharding)
- More control over performance tuning

> "In large-scale systems, foreign keys often move from the database schema to service contracts." — Common microservices design principle

---

## Conclusion

Deadlocks are an unavoidable risk in transactional databases, especially when concurrency and referential integrity intersect. Both MySQL and PostgreSQL handle them with different internal mechanisms, but the end result is the same: unexpected rollbacks and operational pain.

Whether to use foreign keys or not depends on your system's needs:
- Favor **foreign keys** when data integrity is critical and throughput is moderate
- Favor **application-enforced rules** when scaling high-write, distributed systems

Understanding locking behavior, implementing strategies like gap insertion intent, and analyzing access patterns are key to building deadlock-resilient systems—regardless of your database of choice.
