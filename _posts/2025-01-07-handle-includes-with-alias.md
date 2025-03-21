---
layout: post
title: Handling Ordering in Rails with includes and Aliased Joins
date: "2025-01-07"
categories: includes eager-loading rails activerecord
---
# Handling Ordering in Rails with includes and Aliased Joins

When working with ActiveRecord in Rails, it's common to use `includes` to eager-load associations and prevent N+1 queries. However, issues arise when ordering by an associated table's column—especially if Rails aliases the table name in SQL.

In this article, we’ll explore different approaches to ordering records without breaking eager loading and causing unexpected errors.

## The Problem: Ordering by an Associated Table

Consider the following query:

```ruby
report.viewers
  .includes(user: :organization)
  .order("users.last_name_alphabet DESC")
```

### 🚨 Potential Issues:

- **Missing Join**: `includes(:user)` does **not** guarantee a SQL JOIN. If Rails decides to load `users` in a separate query, the `ORDER BY users.last_name_alphabet` will fail.
- **Aliased Table Name**: If Rails **automatically assigns an alias** to `users`, referencing `users.last_name_alphabet` directly will cause an error.

## Fixing the N+1 Query Problem: Two Approaches

### 1️⃣ Using a Single Big Query (JOIN)

To ensure all data is retrieved in a single SQL query, we can force a `JOIN` using `references`:

```ruby
report.viewers
  .includes(user: :organization)
  .references(:user)
  .order("users.last_name_alphabet DESC")
```

#### ✅ Pros:
- Ensures everything is fetched in one query, reducing overall database load.
- Prevents N+1 issues by retrieving all necessary data at once.

#### ⚠️ Cons:
- Can result in **huge queries** when multiple associations are included, leading to performance issues.
- Increases memory consumption because all data is loaded at once.

#### Example of the Generated SQL:

```sql
SELECT viewers.*, users.* FROM viewers
LEFT JOIN users ON users.id = viewers.user_id
ORDER BY users.last_name_alphabet DESC;
```

🔹 **Dangerous Scenario**:
If `users` has a large number of columns or there are additional complex joins (e.g., joining `organizations`), this query can slow down significantly.

---

### 2️⃣ Using Multiple Queries (Eager Loading)

Alternatively, we can allow Rails to run multiple queries while still preventing N+1 queries:

```ruby
report.viewers
  .includes(user: :organization)
  .order(User.arel_table[:last_name_alphabet].desc)
```

#### ✅ Pros:
- Loads `viewers` first, then fetches associated `users` and `organizations` in separate queries.
- Reduces query complexity, making it more efficient in cases with large datasets.
- Uses indexed lookups instead of potentially costly joins.

#### ⚠️ Cons:
- Rails may not automatically apply the order to the in-memory objects after retrieval.
- Can still cause multiple queries, increasing overall query count.

#### Example of the Generated SQL:

```sql
SELECT * FROM viewers;
SELECT * FROM users WHERE id IN (...);
SELECT * FROM organizations WHERE id IN (...);
```

✅ **Better Performance for Large Datasets**:
Instead of one massive query with joins, Rails fetches necessary data separately, reducing memory overhead.

---

## Understanding `references` and When to Use It

The `references` method in ActiveRecord ensures that `includes` performs an SQL JOIN instead of a separate query. If ordering by an associated table’s column, adding `references` helps avoid missing table errors:

```ruby
report.viewers
  .includes(user: :organization)
  .order("users.last_name_alphabet DESC")
  .references(:user)
```

### ✅ Why Use `references(:user)`?
- **Forces a JOIN**, ensuring the `users` table is included in the query.
- **Prevents missing table errors** when ordering by an associated column.

🚨 However, `references` alone **does not solve aliasing issues**, which is where Arel comes in.

## Solution 1: Use Arel to Handle Table Names Dynamically

Arel helps us reference columns dynamically without worrying about aliasing:

```ruby
report.viewers
  .includes(user: :organization)
  .order(User.arel_table[:last_name_alphabet].desc)
```

### ✅ Why This Works:
- `User.arel_table[:last_name_alphabet]` ensures the column reference is **dynamic**.
- Avoids hardcoding `users.last_name_alphabet`, making it **resilient to aliasing**.

## Solution 2: Ensure `users` is in the Query Using `left_joins`

If ordering still fails, force `users` into the query using `left_joins`:

```ruby
report.viewers
  .includes(user: :organization)
  .left_joins(:user)
  .order(User.arel_table[:last_name_alphabet].desc)
```

### 🔹 When to Use This:
- If Rails optimizes `includes(:user)` into a **separate query**, `left_joins(:user)` ensures `users` is part of the main query.
- Useful when ordering by an associated table’s column **without breaking eager loading**.

## Solution 3: Check for Table Aliases in SQL

To verify if Rails is aliasing `users`, inspect the generated SQL:

```ruby
puts report.viewers
  .includes(user: :organization)
  .order(User.arel_table[:last_name_alphabet].desc)
  .to_sql
```

If the output shows something like:

```sql
SELECT ... FROM viewers
LEFT JOIN users AS u ON u.id = viewers.user_id
ORDER BY users.last_name_alphabet DESC;
```

🚨 **This will fail** because `users.last_name_alphabet` does not exist (it’s `u.last_name_alphabet`).

✅ Fix: Reference the correct alias dynamically:

```ruby
user_alias = report.viewers.arel_table.alias('u')
report.viewers
  .joins("LEFT JOIN users AS u ON u.id = viewers.user_id")
  .order("u.last_name_alphabet DESC")
```

## Comparison Table: Which Approach to Use?

| Approach                                                                                     | Fixes N+1? | Prevents Aliasing Issues?     | Ensures `users` is in Query?       |
| -------------------------------------------------------------------------------------------- | ---------- | ----------------------------- | ---------------------------------- |
| `includes(:user).order("users.last_name_alphabet DESC")`                                     | ✅          | ❌ (Fails if alias is applied) | ❌ (Might run a second query)       |
| `includes(:user).references(:user).order("users.last_name_alphabet DESC")`                  | ✅          | ❌ (Fails if alias is applied) | ✅                                  |
| `includes(:user).order(User.arel_table[:last_name_alphabet].desc)`                           | ✅          | ✅                             | ❌ (Might still use a second query) |
| `includes(:user).left_joins(:user).order(User.arel_table[:last_name_alphabet].desc)`         | ✅          | ✅                             | ✅                                  |
| `joins("LEFT JOIN users AS u ON u.id = viewers.user_id").order("u.last_name_alphabet DESC")` | ❌          | ✅                             | ✅                                  |

## Conclusion

- **Use a single JOIN query (`references`) for simple cases but avoid it for large datasets**.
- **For large datasets, prefer multiple queries (`includes` without `references`) to avoid performance issues**.
- **If aliasing is detected**, manually reference the alias (`u.last_name_alphabet`).
- **Arel is the safest and most flexible way to reference columns** while avoiding SQL errors.

By understanding how Rails generates SQL and when aliasing occurs, we can confidently sort records while avoiding N+1 pitfalls. 🚀


