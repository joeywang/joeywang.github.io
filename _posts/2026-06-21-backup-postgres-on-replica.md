---
title: "Why pg_dump backups on a PostgreSQL replica fail intermittently"
description: "Running pg_dump on a PostgreSQL replica can fail with conflict with recovery errors because the backup is a long read transaction colliding with WAL replay."
date: 2026-06-21
categories: [Database]
tags: [postgresql, database, backup]
---

<audio controls preload="metadata" src="/assets/audio/backup-postgres-on-replica-summary.ogg">
  Your browser does not support the audio element.
</audio>


A cron job kicks off a `pg_dump` on a read replica at 3 AM. Backups run there for a logical reason: they're resource-heavy, and you want to keep that CPU and disk I/O off the primary where actual users are.

The next morning brings a failed job alert with a message that looks familiar if you've fought replica conflicts before:

```text
ERROR: canceling statement due to conflict with recovery
DETAIL: User query might have needed to see row versions that must be removed.

```

A backup isn't a user query. It's just a backup. So why is the replica killing its own safety net?

Here's why backing up from a replica is a well-known trap, how the conflict actually plays out, and the cleanest production fixes.

---

## The core problem: a backup is one giant query

A backup isn't a magical snapshot. It's one long-running read transaction. When `pg_dump` starts, it opens a transaction with `REPEATABLE READ` isolation, because it needs a frozen, consistent view of the database from that exact moment so that table A matches table B, even if the backup takes three hours.

While the backup scans tables on the replica, the primary keeps handling live production traffic. That creates a collision course:

1. **The old row:** a user updates or deletes a row on the primary. The primary runs `VACUUM` to clean up the old version.
2. **The WAL stream:** the primary writes this cleanup event into the write-ahead log and streams it to the replica.
3. **The standby delay:** the replica receives the log and needs to delete that old row version to stay in sync, but notices `pg_dump` is still running and still reading that exact row.
4. **The ultimatum:** the replica waits for a grace period, usually 30 seconds. The backup won't finish in 30 seconds, so the replica prioritizes replication over the backup and cancels the backup's query to apply the update.

---

## Why doesn't `hot_standby_feedback` save the backup?

You might expect turning on `hot_standby_feedback` to fix this: the replica tells the primary not to vacuum those rows. It helps, but backups routinely break through that shield for two reasons.

* **The replication gap.** If the primary is processing heavy bulk writes while the backup runs, the replica can fall slightly behind in replaying logs. Once the replica lags by even a few seconds, its feedback message reaches the primary too late, after the primary has already vacuumed the rows. When those WAL entries land on the replica, the conflict is unavoidable and the backup dies.
* **Log shipping versus streaming.** If the replica restores from archived WAL files (`restore_command`) rather than a live network stream (`primary_conninfo`), `hot_standby_feedback` cannot communicate upstream at all. The primary is blind to the backup running on the replica.

---

## Fixing it in production

You don't have to move backups back to the primary and slow down your users. Three approaches work.

### 1. Raise the standby delays

The quick fix: tell the replica to give the backup hours of breathing room instead of seconds. Set this in `postgresql.conf` on the read replica:

```ini
# If the replica streams live from the primary:
max_standby_streaming_delay = '4h'  # gives the backup 4 hours to finish

# If the replica restores from archived WAL files:
max_standby_archive_delay = '4h'

```

When a conflict occurs now, the replica pauses replication for up to four hours to let the backup finish. The trade-off: replica data goes stale while the backup runs, then catches up rapidly once it's done.

### 2. Pair `hot_standby_feedback` with a physical replication slot

If you can't afford replication lag during the backup window, pair `hot_standby_feedback = on` with a physical replication slot on the primary. The slot forces the primary to track the replica's exact position: when the replica needs those rows kept around, the primary stores the old WAL data on its own disk instead of discarding it. The trade-off is that a long backup grows the primary's disk usage temporarily, so give it headroom.

### 3. Drop `pg_dump` for physical backups

If the database is hundreds of gigabytes or terabytes, a logical backup like `pg_dump` on a replica is the wrong tool regardless of tuning. Physical backup tools like pgBackRest, Barman, or native cloud snapshots (AWS Aurora/RDS snapshots) don't open an MVCC transaction at all. They copy the raw data blocks and WAL streams directly, so they don't care about row versions or read consistency at the SQL level and are immune to recovery conflicts.

## The principle

For small to medium databases (under 50GB), keep the backup on the replica, turn on `hot_standby_feedback`, and raise `max_standby_streaming_delay` to a window long enough for the backup to finish. Past that scale, stop using `pg_dump` on a replica altogether and move to a physical backup tool that bypasses the database engine and the conflict trap entirely.
