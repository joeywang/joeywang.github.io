---
layout: post
title:  "Zombie PostgreSQL replicas: the WAL segment removed deadlock"
description: "PostgreSQL replicas on Kubernetes can get stuck in a WAL segment removed loop that passes liveness checks, and three fixes stop it for good."
date:   2026-06-27 00:00:00
categories: [Database]
tags: [postgresql, kubernetes, database, devops]
---

<audio controls preload="metadata" src="/assets/audio/2026-06-27-zombie-replica-summary.ogg">
  Your browser does not support the audio element.
</audio>

If you run PostgreSQL on Kubernetes with an operator like Kubegres, CloudNativePG, or Crunchy Data, automated failover usually just works. But there's a failure mode where a replica isn't dead and isn't really alive either: a zombie replica.

It loops endlessly logging a fatal error while Kubernetes liveness probes keep reporting that everything is fine. Here's why this happens, how the community handles it, and how to build a hands-off automated fix.

---

## Anatomy of the trap

It starts with a log trail that looks something like this:

```text
2026-07-05 08:51:47 GMT [998627]: FATAL: could not receive data from WAL stream: 
ERROR: requested WAL segment 00000010000013DC0000002E has already been removed
2026-07-05 08:51:47 GMT [912472]: LOG: waiting for WAL to become available at 13DC/2E002000

```

### What's happening underneath

1. **The disconnect:** due to a network blip, a noisy neighbor, or a node restart, the replica briefly drops its connection to the primary.
2. **The purge:** while the replica is reconnecting, the primary keeps processing write traffic. It hits a checkpoint, decides older WAL segments are no longer needed locally, and recycles them to save disk space.
3. **The deadlock:** the replica wakes up, reconnects, and asks for WAL segment `X`. The primary has already discarded it. The replica restarts its WAL receiver and tries again five seconds later, forever.

### The false positive health check

While the replica is trapped in this loop, the PostgreSQL engine is technically still running, in `hot standby` recovery mode. Standard Kubernetes liveness probes rely on `pg_isready` or `SELECT 1;`, and both of those succeed: the process answers, so the probe passes.

A connection proxy like `pgpool-II` notices the replication lag climbing and correctly stops routing read traffic to the replica. But Kubernetes never restarts the pod, because the liveness probe keeps passing. The result is a broken cluster that needs a human to manually delete the Persistent Volume Claim (PVC) and force a re-clone.

---

## Three tiers of fix

GitHub issues and Stack Overflow threads generally converge on three tiers of resolution, ordered by effort and by how completely they solve the problem.

### Tier 1: `wal_keep_size`

The simplest mitigation is to force the primary to hold onto its history longer. By default, PostgreSQL might keep only a few hundred megabytes of WAL segments.

Configure the Kubegres `ConfigMap` to alter this buffer:

```ini
# For PostgreSQL 13+ (allocate a generous safety buffer on disk)
wal_keep_size = 20480MB 

```

This prevents the issue during short outages or routine node maintenance. But it's a race against time: if a replica goes down over a long weekend, or write volume spikes, the primary will still eventually cross the threshold, purge the logs, and trigger the deadlock anyway.

### Tier 2: continuous archiving

The structural fix within PostgreSQL is WAL archiving. Instead of relying purely on a direct stream between primary and replica, the primary pushes its WAL segments to a shared object store (AWS S3, MinIO, or a shared NFS volume).

When a replica discovers it's missing a segment on the live stream, it switches strategies:

```ini
# In the replica configuration
restore_command = 'cp /mnt/wal_archive/%f %p'

```

The replica fetches the missing segments from the archive, catches up to the current timeline, and reinstates live streaming without a dropped packet.

## Tier 3: automated self-healing

A zero-intervention fix inside Kubernetes, without managing a full external WAL archive, means teaching the cluster to detect the difference between a genuinely healthy database and a standby stuck in a WAL loop. That means a custom sidecar container or a cluster `CronJob` that looks past the surface-level `pg_isready` check.

### 1. The detection query

Instead of testing whether the database is awake, test whether the replication data receiver is active. Run this inside the replica monitoring logic:

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

### 2. The auto-heal script

If the check returns `true` and `0`, the data directory on that replica is no longer useful. The only path forward is a complete wipe and a fresh `pg_basebackup`.

Deploy a small script with a Kubernetes `ServiceAccount` to run this cleanup:

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

### 3. Adjusting Kubegres settings

For this automation to work, the Kubegres resource definition needs to clean up its storage on lifecycle events. Set `spec.failover.pvc` if you want the operator to rebuild missing volumes automatically:

```yaml
spec:
  failover:
    pvc: delete   # Automatically purges old PVC state when instances are recreated

```

---

## Which tier fits

| Strategy | Effort | Storage overhead | Best for |
| --- | --- | --- | --- |
| `wal_keep_size` | Low, single config line | Moderate, local primary disk | Small environments with low-to-medium write throughput |
| WAL archiving | Medium, needs S3/MinIO | High, long-term retention storage | Production databases with compliance or zero-data-loss requirements |
| K8s auto-wipe script | Medium, CronJob/sidecar | None | Cloud-native setups where data can be re-cloned quickly over internal networks |

None of these are mutually exclusive. A reasonable default is `wal_keep_size` as cheap insurance, WAL archiving if the compliance story requires it, and the auto-wipe script as the backstop for whatever slips through both.
