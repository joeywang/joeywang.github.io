---
layout: post
title: "Postgres conflict with recovery: why replicas cancel queries"
description: "A PostgreSQL replica cancels long queries with conflict with recovery errors during VACUUM replication, and hot_standby_feedback fixes it without downtime."
date:   2026-06-20 14:41:26 +0100
categories: [Database]
tags: [postgresql, database, performance]
---

<audio controls preload="metadata" src="/assets/audio/cancelling-with-recovery-summary.ogg">
  Your browser does not support the audio element.
</audio>


If you run a PostgreSQL database at any scale, there's a good chance you've split your traffic: writes on the primary, heavy reads and analytics on a read replica. It works well, until the day your background workers or analytics dashboards start throwing this:

```text
PG::TRSerializationFailure: ERROR: canceling statement due to conflict with recovery
DETAIL: User query might have needed to see row versions that must be removed.

```

It's annoying, it feels random, and if you have a load balancer like PgPool in front of the database, it gets confusing fast.

Here's why this happens, why your load balancer might be hiding it from you, and how to fix it without bringing down production.

---

## The root cause: MVCC across a replica

To understand this error, you have to understand how Postgres deletes data.

When you run a `DELETE` or an `UPDATE` in Postgres, it doesn't erase the data from disk immediately. It creates a new version of the row and marks the old one as dead. Later, a background process called `VACUUM` sweeps up those dead rows (tuples) and frees the disk space.

Now bring the read replica into the picture:

```
[ Primary Database ]                         [ Read Replica ]
     |                                             |
  1. Deletes a row & VACUUMs it                    |
     |                                             |
  2. Sends WAL log (Cleanup) --------------------> | 3. Running a 45-second report
                                                       (looking at that deleted row)
                                                   |
                                          Replication must proceed.
                                          Your query gets killed.

```

1. **On the primary:** a vacuum runs. Nobody is looking at these old rows anymore, so they get deleted.
2. **Replication:** the primary writes this cleanup into the write-ahead log (WAL) and streams it to the replica.
3. **The clash on the replica:** the replica receives the instruction to delete those old rows. But a user is currently running a heavy, 45-second reporting query on the replica that is actively reading those exact rows.

The replica is stuck. If it waits for your query to finish, replication falls behind and the replica's data goes stale. If it applies the update, it breaks your query.

Postgres chooses replication. It waits for a grace period, defined by `max_standby_streaming_delay` and usually 30 seconds. If your query isn't done by then, Postgres cancels it and throws the `conflict with recovery` error.

---

## Why PgPool can hide this from you for years

Some teams have run a replica for years without ever seeing this error, then hit it out of nowhere.

If you use **PgPool-II** for load balancing, you might have replication gap detection turned on. If the replica falls behind the primary by more than a few seconds, PgPool stops sending read traffic to it and routes everything back to the primary.

That acts as an accidental shield. During massive bulk writes or heavy data dumps, the replication gap spikes, PgPool cuts replica traffic, and users never touch the replica while the dangerous cleanup logs replay.

But PgPool doesn't protect you from long queries. If the primary deletes just a few rows, replication lag stays at a normal 0 or 1 second. PgPool sees nothing wrong. But if a user on the replica is running a 40-second query that touches those exact rows, the 30-second grace period ticks down and the query gets canceled. PgPool never sees it coming, because the overall replication gap looked completely normal.

---

## How to fix it without restarting production

You don't need a maintenance window for this. Three things fix it in practice.

### 1. `hot_standby_feedback`

Turning this on tells the replica to talk back to the primary: it needs certain old rows, so hold off vacuuming them. You can enable it without restarting the database.

Run this on your replica:

```sql
ALTER SYSTEM SET hot_standby_feedback = 'on';
SELECT pg_reload_conf(); -- reloads config on the fly

```

Turn it on at the primary level too (`ALTER SYSTEM SET hot_standby_feedback = 'on'`). The primary ignores the setting while acting as master, but any new replica spun up via `pg_basebackup` inherits the config and boots up already protected.

### 2. Pair it with `statement_timeout`

Turning on `hot_standby_feedback` introduces a new risk: if someone opens a console on the replica and leaves a query hanging for five hours, the primary stops vacuuming entirely. That causes table bloat and eats disk space on the primary.

Set a reasonable `statement_timeout` on the replica to prevent that:

```ini
statement_timeout = '5min' # kills rogue replica queries before they bloat the primary

```

### 3. Retry in application code

This is a serialization failure, so the error is transient. Run the same query a second later and it will almost certainly succeed, since the replica has finished replaying the logs by then.

If you're using Rails, Laravel, or Django, wrap heavy replica reads in a basic retry block that catches `PG::TRSerializationFailure` and tries once more before giving up.

## The principle

The `conflict with recovery` error isn't a sign the database is broken. It's the database working exactly as designed to keep replicated data synchronized. For most production apps, `hot_standby_feedback = on`, capped with a reasonable `statement_timeout`, and inherited by every new replica, is the quiet, error-free default.
