---
layout: post
title: "To `Type` or to `ID`: Mastering Polymorphic Indexing in MySQL & Rails"
date: 2026-01-25
categories: [database, mysql, rails, performance]
tags: [polymorphic associations, indexing strategies, performance
optimization]

---

# To `Type` or to `ID`: Mastering Polymorphic Indexing in MySQL & Rails

When building polymorphic associations in Ruby on Rails, the database schema usually looks straightforward: a `relation_id` (Integer) and a `relation_type` (String). But beneath the surface, a debate rages: **Should your composite index start with the ID or the Type?**

While Rails defaults to `[type, id]`, high-performance scenarios—especially when IDs are "mostly unique" (like when Athlete IDs are much larger than classroom IDs)—might tempt you to flip the script.

## The Anatomy of a Polymorphic Query

In Rails, a typical lookup for a `FormationPositionView` looks like this:

```sql
SELECT * FROM game_activities 
WHERE relation_id = 1222 
AND relation_type = 'Planning::Private::Models::FormationPositionView';

```

In MySQL, the engine uses a **B-Tree index**. To understand which index order is best, we have to look at how the engine "traverses" that tree.

---

## Strategy 1: The Standard `[type, id]`

This is the Rails default. It treats the `type` as a namespace.

### The Pros

* **Broad Utility:** Supports both the full lookup (Type + ID) and "Type-only" queries (e.g., finding all activities for all Athletes).
* **Data Locality:** All records for a specific model are stored physically near each other in the index leaf nodes.
* **Left-Prefix Rule:** You don't need a separate index for the `relation_type`.

### The Cons

* **String Comparison:** Comparing long class names (strings) is technically slower than comparing integers, though MySQL's prefix compression makes this difference negligible for most.

---

## Strategy 2: The "High-Selectivity" `[id, type]`

You might choose this if your IDs are diverse (e.g., Athlete IDs are in the millions, while classroom IDs are in the hundreds).

### The Pros

* **Fast Narrowing:** Since the ID is highly selective (unique or nearly unique), the database narrows the search space to a few rows almost instantly.
* **Numerical Speed:** Jumping through a tree of integers is the "happy path" for CPU registers.

### The Cons

* **Narrow Utility:** This index is useless if you ever need to find all activities for a specific Type without an ID.
* **Fragmentation:** Because IDs are added chronologically across different types, the data for a single "Type" will be scattered across the index.

---

## Strategy 3: The "Covering Index" (The Real Secret Sauce)

Regardless of the order, the biggest performance win comes from the fact that both columns are in the index. This creates a **Covering Index**.

When both columns are in the index, MySQL never has to look at the "Table Data" (disk) to confirm the query. It finds the answer entirely within the index RAM.

---

## Which one should you pick?

| Requirement | Pick `[type, id]` | Pick `[id, type]` |
| --- | --- | --- |
| **Standard Rails App** | ✅ (Best all-rounder) | ❌ |
| **Highly Skewed Data** | ❌ (If one type has 99% of rows) | ✅ |
| **UUIDs as IDs** | ✅ (Consistency) | ✅ (Slightly faster jump) |
| **Reporting/Analytics** | ✅ (Filter by type easily) | ❌ |

## The Developer's Decision Matrix

### 1. The "Almost Unique" Scenario

If your `student_id` is 9 digits and `classroom_id` is 4, they rarely overlap. In this case, `[id, type]` will find the record in slightly fewer CPU cycles. However, you lose the ability to query by Type alone.

### 2. The Rails Way

Rails often performs "Dependent Destroys" or "Eager Loading" based on the Type. If you use `[id, type]`, these internal Rails operations may trigger **Full Table Scans** because they lack a `type` prefix.

---

## Final Verdict

For 95% of applications, **stick to the Rails default: `[:relation_type, :relation_id]**`.

The "speed" gained by putting the ID first is measured in microseconds, but the "utility" lost is measured in potential production bottlenecks when you try to run a query without an ID.

**Pro-Tip:** If you have massive scale and truly need both, don't create two composite indexes. Create one composite `[type, id]` and one single-column index on `[id]`. This gives you the best of both worlds with minimal overhead.
