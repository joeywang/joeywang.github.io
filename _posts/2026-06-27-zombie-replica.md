---
layout: post
title:  "The Zombie Replica: Solving PostgreSQL's 'WAL Segment Removed' Deadlock on Kubernetes"
description: "If you run PostgreSQL on Kubernetes using an operator like Kubegres, CloudNativePG, or Crunchy Data, you are likely no stranger to the peace of mind automated"
date:   2026-06-27 00:00:00
categories: PostgreSQL
---

# The Zombie Replica: Solving PostgreSQL's "WAL Segment Removed" Deadlock on Kubernetes

<audio controls preload="metadata" src="/assets/audio/2026-06-27-zombie-replica-summary.ogg">
  Your browser does not support the audio element.
</audio>

If you run PostgreSQL on Kubernetes using an operator like Kubegres, CloudNativePG, or Crunchy Data, you are likely no stranger to the peace of mind automated failovers bring. But there is a silent killer lurking in the cloud-native database world—a scenario where a replica isn't exactly dead, but it isn't alive either. It becomes a **Zombie Replica**.

It loops endlessly, logging a fatal error, while your Kubernetes liveness probes cheerfully report that everything is fine. Let's dissect why this happens, how the community handles it, and how to build a bulletproof, hands-off automated fix.

---

## The Anatomy of the Trap

The nightmare begins with a classic log trail that looks something like this:

```text
2026-07-05 08:51:47 GMT [998627]: FATAL: could not receive data from WAL stream: 
ERROR: requested WAL segment 00000010000013DC0000002E has already been removed
2026-07-05 08:51:47 GMT [912472]: LOG: waiting for WAL to become available at 13DC/2E002000

```

### What's Happening Under the Hood?

1. **The Disconnect:** Due to a network blip, a noisy neighbor, or a node restart, your replica briefly drops its connection to the primary.
2. **The Purge:** While the replica is catching its breath, your primary database continues processing heavy write traffic. It hits a checkpoint and determines that older Write-Ahead Log (WAL) segments are no longer needed locally, so it recycles them to save disk space.
3. **The Deadlock:** The replica wakes up, reconnects, and asks for WAL segment `X`. The primary replies, *"Sorry, I already threw that out."* The replica panics, restarts its WAL receiver, and tries again 5 seconds later. Forever.

### The "False Positive" Health Check

Here is the real kicker: while the replica is trapped in this loop, **the PostgreSQL database engine is technically running.** It is in `hot standby` recovery mode.

Because standard Kubernetes liveness probes usually rely on `pg_isready` or `SELECT 1;`, the database answers **"YES, I AM HEALTHY!"** ```
┌─────────────────────────────────────────────────────────────┐
│                       KUBERNETES POD                        │
│                                                             │
│  ┌───────────────────────┐       ┌───────────────────────┐  │
│  │    Liveness Probe     │◄───── Milan, I am alive!      │  │
│  │     (pg_isready)      │       │                       │  │
│  └───────────────────────┘       │  PostgreSQL Instance  │  │
│                                  │ (Stuck in WAL Loop)   │  │
│  ┌───────────────────────┐       │                       │  │
│  │     pgpool-II /       │◄─────X│                       │  │
│  │   Readiness Probe     │  Lag  └───────────────────────┘  │
│  │ (Isolates from Reads) │  Max                             │
│  └───────────────────────┘                                  │
└─────────────────────────────────────────────────────────────┘

```

Your connection proxy (like `pgpool-II`) will notice the astronomical replication lag and correctly stop routing read traffic to it. However, Kubernetes will never restart the pod because the liveness probe keeps passing. You are left with a broken cluster that requires a human to manually delete the Persistent Volume Claim (PVC) and force a re-clone.

---

## The Community Consensus: How to Fight the Zombie

Engineers across GitHub issues and StackOverflow threads generally lean toward three tiers of resolution. Let's break them down by complexity and effectiveness.

### Tier 1: Proactive Insurance (`wal_keep_size`)
The simplest mitigation is to force the primary node to hold onto its history longer. By default, PostgreSQL might only keep a few hundred megabytes of WAL segments. 

You can configure your Kubegres `ConfigMap` to alter this buffer:

```ini
# For PostgreSQL 13+ (Allocate a generous safety buffer on disk)
wal_keep_size = 20480MB 

```

* **Pros:** Prevents the issue during short outages or routine node maintenance.
* **Cons:** It is a race against time. If your replica goes down over a long weekend, or your write volume spikes, the primary will still eventually cross this threshold and purge the logs, triggering the deadlock anyway.

### Tier 2: Continuous Archiving (The Structural Solution)

The textbook way to solve this natively within PostgreSQL is to configure **WAL Archiving**. Instead of relying purely on a direct network stream between primary and replica, the primary pushes its WAL segments to a highly available shared object store (like AWS S3, MinIO, or a shared NFS volume).

When a replica discovers it's missing a WAL segment on the live stream, it switches strategies:

```ini
# In the replica configuration
restore_command = 'cp /mnt/wal_archive/%f %p'

```

The replica seamlessly fetches the missing segments from the archive, catches up to the current timeline, and reinstates live streaming without a single dropped packet.

---

## Tier 3: Automated Self-Healing (The Cloud-Native Way)

If you want a true, zero-intervention auto-fix within Kubernetes without managing a massive external WAL archive, you must teach your cluster how to detect the difference between a genuinely healthy database and a standby stuck in a WAL loop.

You can achieve this by implementing a custom sidecar container or a cluster `CronJob` that looks past the surface-level `pg_isready` check.

### 1. The Detection Query

Instead of testing if the database is awake, test if the replication data receiver is active. Run this inside your replica monitoring logic:

```sql
SELECT 
    pg_is_in_recovery() AS in_recovery,
    (SELECT count(*) FROM pg_stat_wal_receiver()) AS active_receivers;

```

| `in_recovery` | `active_receivers` | Cluster State |
| --- | --- | --- |
| `false` | `0` | **Primary Node:** Healthy |
| `true` | `1` | **Replica Node:** Healthy & Streaming |
| `true` | `0` | **Zombie Replica:** Deadlocked on missing WAL |

### 2. The Auto-Heal Bash Script

If your automated check returns `true` and `0`, the data directory on that replica is officially historical garbage. The only path forward is a complete wipe and a fresh `pg_basebackup`.

You can deploy a small script with a Kubernetes `ServiceAccount` to execute the following clean-up:

```bash
#!/usr/bin/env bash
set -eo pipefail

NAMESPACE="database"
REPLICA_POD="mypostgres-replica-0"
REPLICA_PVC="postgres-data-mypostgres-replica-0"

echo "Checking health of streaming replication receiver..."
ACTIVE_RCV=$(kubectl exec -n $NAMESPACE $REPLICA_POD -c postgres -- psql -U postgres -t -c "SELECT count(*) FROM pg_stat_wal_receiver();" | tr -d '[:space:]')

if [ "$ACTIVE_RCV" -eq "0" ]; then
    echo "CRITICAL: Replica is stuck in an unrecoverable loop. Initiating auto-wipe..."
    
    # 1. Terminate the zombie pod
    kubectl delete pod $REPLICA_POD -n $NAMESPACE
    
    # 2. Delete the underlying PVC to prevent reusing corrupted state
    kubectl delete pvc $REPLICA_PVC -n $NAMESPACE
    
    echo "PVC purged. Kubegres Operator will now provision clean storage and re-clone from Primary."
fi

```

### 3. Adjusting Kubegres Settings

For this automation to work seamlessly, ensure your Kubegres resource definition is configured to clean up its storage footprints upon lifecycle events. Ensure `spec.failover.pvc` is handled correctly if you want the operator to completely rebuild missing volumes:

```yaml
spec:
  failover:
    pvc: delete   # Automatically purges old PVC state when instances are recreated

```

---

## Summary Strategy Matrix

Every team has different risk profiles. Use this matrix to choose your path:

| Strategy | Implementation Effort | Storage Overhead | Best Used For |
| --- | --- | --- | --- |
| **`wal_keep_size`** | Low (Single Config Line) | Moderate (Local Primary Disk) | Small environments with low-to-medium write throughput. |
| **WAL Archiving** | Medium (Requires S3/MinIO) | High (Long-term retention storage) | Enterprise production databases with strict compliance and zero-data-loss requirements. |
| **K8s Auto-Wipe Script** | Medium (CronJob/Sidecar Setup) | None | High-velocity cloud-native setups where data sets can be cloned quickly over internal networks. |
