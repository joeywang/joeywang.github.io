---
layout: post
title: "The Phantom Postgres Ghost: Tracking Down \"Conflict with Recovery\" Errors on Read Replicas"
date:   2026-06-20 14:41:26 +0100
categories: Postgres
tags: Postgres
---

# The Phantom Postgres Ghost: Tracking Down "Conflict with Recovery" Errors on Read Replicas

If you are running a modern application with a PostgreSQL database, there is a high chance you eventually split your traffic. You kept your writes on the Primary database and routed your heavy reads and analytics to a Read Replica. It’s a great setup. Everything is blazing fast—until one day, your background workers or analytics dashboards start throwing this cryptic nightmare:

```text
PG::TRSerializationFailure: ERROR: canceling statement due to conflict with recovery
DETAIL: User query might have needed to see row versions that must be removed.

```

It’s annoying, it feels random, and if you have load balancers like PgPool in front of your database, it can be downright confusing to debug.

Let’s pull back the curtain on why this happens, why your load balancer might accidentally be hiding it from you, and how to fix it without bringing down production.

---

## The Root Cause: A Story of Multi-Version Concurrency Control (MVCC)

To understand this error, you have to understand how Postgres deletes data.

When you run a `DELETE` or an `UPDATE` in Postgres, it doesn’t actually erase the data from the disk immediately. Instead, it creates a new version of the row and marks the old one as "dead." Later on, a background process called `VACUUM` comes along, sweeps up those dead rows (tuples), and frees up the disk space.

Now, let’s introduce the Read Replica into the mix.

```
[ Primary Database ]                         [ Read Replica ]
     |                                             |
  1. Deletes a row & VACUUMs it                    |
     |                                             |
  2. Sends WAL log (Cleanup) --------------------> | 3. Running a 45-second report
                                                       (Looking at that deleted row!)
                                                   |
                                            🚨 THE CLASH 🚨
                                     Replication must proceed. 
                                     Your query gets killed.

```

1. **On the Primary:** A vacuum happens. The primary says, *"Awesome, nobody here is looking at these old rows anymore. Delete them!"*
2. **The Replication:** The primary writes this cleanup action into the Write-Ahead Log (WAL) and streams it to your replica.
3. **The Clash on the Replica:** Your replica receives the instruction to delete those old rows. But wait! A user is currently running a heavy, 45-second reporting query on the replica that is *actively looking* at those exact rows.

The replica is stuck in a hard place. If it waits for your query to finish, replication falls behind, and your replica data becomes stale. If it forces the update, it breaks your query.

Postgres chooses replication. It waits for a grace period (defined by `max_standby_streaming_delay`, usually 30 seconds). If your query isn’t done by then, Postgres pulls the plug and throws the `conflict with recovery` error.

---

## The PgPool Plot Twist: Why You Realized This Late

Some dev teams look at this error and say, *"Wait, we’ve been running a replica for years with feedback turned off, and we've never seen this. Why now?"*

If you use a tool like **PgPool-II** for load balancing, you might have replication gap detection turned on. If the replica falls behind the primary by more than a few seconds, PgPool aggressively stops sending read traffic to the replica and routes it back to the primary.

This acts as an accidental shield! During massive bulk writes or heavy data dumps, the replication gap spikes, PgPool pulls the plug on replica traffic, and your users are kept safely away from the replica while the dangerous cleanup logs are replayed.

**But PgPool doesn’t protect you from long queries.** If the primary deletes just a few rows, the replication lag remains at a perfect 0 or 1 second. PgPool thinks everything is fine. But if a user on the replica happens to be running a 40-second query that touches those exact few rows, the 30-second grace period will tick down, and *bam*—query canceled. PgPool never saw it coming because the overall replication gap was completely normal.

---

## How to Fix It (Without Restarting Production)

You don’t have to live with these errors, and you don’t need to schedule a 2:00 AM maintenance window to fix them. Here are the three best ways to handle it.

### 1. The Zero-Downtime Silver Bullet: `hot_standby_feedback`

You can tell your replica to actively talk back to the primary database. By turning on `hot_standby_feedback`, the replica whispers to the primary: *"Hey, I'm currently running a query that needs these specific old rows. Hold off on the vacuum for a minute."*

The best part? You can enable this **without restarting the database**.

Run this on your replica:

```sql
ALTER SYSTEM SET hot_standby_feedback = 'on';
SELECT pg_reload_conf(); -- Reloads config on the fly!

```

> 💡 **Pro-Tip:** Turn this on at the **Primary** database level too (`ALTER SYSTEM SET hot_standby_feedback = 'on'`). The primary will ignore the setting while acting as master, but whenever you spin up a *new* replica via `pg_basebackup`, the new node will automatically inherit this config and boot up protected.

### 2. Pair it with a Safety Net (`statement_timeout`)

If you turn `hot_standby_feedback` on, you run a new risk: if a developer opens a database console on the replica and leaves a query hanging open for 5 hours, the primary database will stop vacuuming entirely. This causes **table bloat** and eats up disk space on your primary.

To prevent this, always set a reasonable `statement_timeout` on your replica:

```ini
statement_timeout = '5min' # Kills rogue replica queries before they bloat the primary

```

### 3. Handle it in App Code (The Retry Mechanism)

Because this is a serialization failure, the error is transient. If you run the exact same query one second later, it will almost certainly succeed because the replica has finished replaying the logs.

If you are using a framework like Ruby on Rails, Laravel, or Django, wrap your heavy replica reads in a basic retry block that catches `PG::TRSerializationFailure` and tries one more time before giving up.

---

## Wrap Up

The `conflict with recovery` error isn't a sign that your database is broken; it's a sign that your database is working exactly as designed to keep your data synchronized.

For 90% of production apps, turning **`hot_standby_feedback = on`**, capping it with a reasonable **`statement_timeout`**, and letting your replicas inherit the config from the primary is the sweet spot for a quiet, error-free life.
