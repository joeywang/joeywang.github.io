---
layout: post
title:  "Materialized Views: Speeding Up Queries with a Tradeoff"
description: "Materialized views cache expensive PostgreSQL queries as physical tables, trading storage and refresh cost for fast reads, plus how pgpool fits in."
date:   2024-08-19 14:41:26 +0100
categories: [Database]
tags: [postgresql, database, performance, devops]
---
<audio controls preload="metadata" src="/assets/audio/materialized-view-summary.ogg">
  Your browser does not support the audio element.
</audio>

A materialized view in PostgreSQL is a pre-computed snapshot of a query, stored as a physical table. Instead of re-running a slow query every time, you read the stored result. The tradeoff is that the result goes stale the moment the underlying data changes, and refreshing it is not free.

## Benefits

The main win is speed: a query that takes minutes against the underlying tables can return in seconds from the materialized view.

## Tradeoffs

- **Storage space.** The view replicates the query's result set. A large view can consume significant database space.
- **Data freshness.** Materialized views are not updated automatically. Keeping them accurate means refreshing on a schedule, and frequent refreshes add load.

## PostgreSQL-specific limitations

- **No incremental refresh.** PostgreSQL recomputes the entire materialized view on refresh, even if only a small fraction of the underlying data changed.
- **WAL growth.** Refreshing a large materialized view generates a lot of Write-Ahead Log traffic. If the WAL grows too fast, it can trigger frequent checkpoints and delay replication to standby servers.

## Working around the limitations

**Incremental View Maintenance.** The `pg_ivm` extension adds incremental refresh support outside of core PostgreSQL, cutting refresh overhead and improving freshness.

**Refresh frequency.** Match the refresh interval to how often the underlying data actually changes and how stale a result your application can tolerate. A slight delay in accuracy is often a fair price for a lighter refresh load.

**Archiving.** If the view holds historical data, move older rows to a separate table to shrink the view's storage footprint.

**Configuration.** Raising `max_wal_size` lets the database absorb more changes before a checkpoint, softening the impact of a large refresh on replication. More memory helps too.

## pgpool for replication-aware routing

pgpool is a connection pooler and load balancer that sits in front of a PostgreSQL primary and its standbys. Two features matter here:

- **Stop reading from stale replicas.** When a standby falls behind the primary, pgpool can stop routing read traffic to it, so applications only see current data.
- **Configurable delay thresholds.** You set an acceptable replication delay; if a standby exceeds it, pgpool stops sending reads there.

```
load_balance_mode = on
delay_threshold = 10485760  # 10 MB (adjust as needed)
log_standby_delay = 'always'
health_check_period = 5
health_check_timeout = 20
health_check_user = 'your_health_check_user'
health_check_password = 'your_health_check_password'

health_check_database = 'postgres'
```

Adjust these values to your own replication topology and tolerance for staleness. Materialized views buy you speed; pgpool and a sane refresh schedule are what keep that speed from costing you correctness.
