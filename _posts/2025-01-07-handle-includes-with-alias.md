---
layout: post
title: "Ordering by an Associated Column Without Breaking includes"
description: "Why ordering ActiveRecord results by an associated table's column breaks with includes, and how references, Arel, and left_joins fix it for good."
date: "2025-01-07"
categories: [Rails, Database]
tags: [rails, database, performance, debugging]
---
<audio controls preload="metadata" src="/assets/audio/handle-includes-with-alias-summary.ogg">
  Your browser does not support the audio element.
</audio>

`includes` prevents N+1 queries in Rails, but ordering by a column on the included table introduces a second problem: Rails does not guarantee that `includes` produces a JOIN, and when it does, it can alias the table name in the generated SQL.

## The problem

```ruby
report.viewers
  .includes(user: :organization)
  .order("users.last_name_alphabet DESC")
```

Two things can go wrong here. `includes(:user)` may load `users` in a separate query rather than a JOIN, in which case `ORDER BY users.last_name_alphabet` references a table that isn't in that query's scope and fails. And if Rails does JOIN and assigns `users` an alias, a hardcoded reference to `users.last_name_alphabet` breaks against the alias too.

## Two ways to actually fetch the data

**Force a single JOIN query with `references`:**

```ruby
report.viewers
  .includes(user: :organization)
  .references(:user)
  .order("users.last_name_alphabet DESC")
```

```sql
SELECT viewers.*, users.* FROM viewers
LEFT JOIN users ON users.id = viewers.user_id
ORDER BY users.last_name_alphabet DESC;
```

This gets everything in one round trip, at the cost of a large result set once several associations are joined, more memory, one bigger query instead of several smaller ones.

**Let Rails run separate queries:**

```ruby
report.viewers
  .includes(user: :organization)
  .order(User.arel_table[:last_name_alphabet].desc)
```

```sql
SELECT * FROM viewers;
SELECT * FROM users WHERE id IN (...);
SELECT * FROM organizations WHERE id IN (...);
```

Each query stays small and uses indexed lookups, at the cost of more round trips. Rails does not automatically apply the order to objects loaded this way, which is why the `arel_table` form matters here, more on that below.

## `references` alone doesn't fix aliasing

`references(:user)` forces the JOIN and stops the missing-table error, but it does nothing about aliasing. If Rails still renames `users` to something else in the generated SQL, a hardcoded `users.last_name_alphabet` still fails.

## Arel: reference the column, not the table name

```ruby
report.viewers
  .includes(user: :organization)
  .order(User.arel_table[:last_name_alphabet].desc)
```

`User.arel_table[:last_name_alphabet]` resolves to whatever Rails actually names the table at query time, so it survives aliasing that a hardcoded string wouldn't.

## When `includes` still runs as separate queries

If Rails optimizes `includes(:user)` into a separate query despite the `order`, force `users` into the main query with `left_joins`:

```ruby
report.viewers
  .includes(user: :organization)
  .left_joins(:user)
  .order(User.arel_table[:last_name_alphabet].desc)
```

## Checking what Rails actually generated

```ruby
puts report.viewers
  .includes(user: :organization)
  .order(User.arel_table[:last_name_alphabet].desc)
  .to_sql
```

If the output shows

```sql
SELECT ... FROM viewers
LEFT JOIN users AS u ON u.id = viewers.user_id
ORDER BY users.last_name_alphabet DESC;
```

that query fails, `users.last_name_alphabet` doesn't exist under that alias, only `u.last_name_alphabet` does. Reference the alias directly:

```ruby
report.viewers
  .joins("LEFT JOIN users AS u ON u.id = viewers.user_id")
  .order("u.last_name_alphabet DESC")
```

## Which approach to use

| Approach | Fixes N+1 | Survives aliasing | Guarantees `users` is in the query |
|----------|-----------|--------------------|--------------------------------------|
| `includes(:user).order("users.last_name_alphabet DESC")` | Yes | No | No, may run a second query |
| `+ .references(:user)` | Yes | No | Yes |
| `includes(:user).order(User.arel_table[...].desc)` | Yes | Yes | No, may still run a second query |
| `+ .left_joins(:user)` | Yes | Yes | Yes |
| Raw `joins` with an explicit alias | No | Yes | Yes |

## The principle

`references` for simple cases, kept off for large joined result sets. Arel's `arel_table` whenever the order touches an associated column, because it's the one option that doesn't break the moment Rails decides to alias a table. If ordering still fails after that, `to_sql` will show you exactly which alias to reference by hand.
</content>
