---
layout: post
title: "Upgrading Bitnami Redis Helm Charts Without Downtime"
description: "A runbook for upgrading Bitnami's Redis Helm chart in Kubernetes, covering node migration, debug dry runs, and a tested rollback plan."
date: "2025-01-04"
categories: [DevOps]
tags: [kubernetes, redis, devops, helm]
---

<audio controls preload="metadata" src="/assets/audio/redis-upgrade-with-helm-summary.ogg">
  Your browser does not support the audio element.
</audio>

A Redis cluster deployed through Bitnami's Helm chart is not a version bump you run and forget. Redis is usually the beating heart of caching, sessions, and real-time data for whatever sits behind it, and when the upgrade also has to move pods off nodes scheduled for maintenance, a careless `helm upgrade` can cost you both uptime and data. Here is the sequence that keeps it boring.

## Reconnaissance

Start by knowing exactly what you're moving from and to:

```bash
# Update the chart repository information
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Check available versions and release dates
helm search repo bitnami/redis --versions
```

Note the changelog between your current chart version and the target, then capture the current state:

```bash
# Export current values for review
helm get values redis-production > current-values.yaml

# Examine the deployment history
helm history redis-production
```

```
REVISION    UPDATED                     STATUS        CHART            APP VERSION    DESCRIPTION
1           Thu Mar 10 11:13:22 2024    superseded    redis-16.8.5     6.2.7          Install complete
2           Fri Apr 14 15:42:19 2024    superseded    redis-16.12.3    6.2.7          Configuration update
3           Mon Jul 17 09:05:43 2024    deployed      redis-16.13.1    6.2.7          Scaled replicas
```

If the upgrade also needs to move pods off nodes due for maintenance, check current placement before touching anything:

```bash
# Check which nodes are running Redis pods
kubectl get pods -l app.kubernetes.io/name=redis -o wide

# Review node labels and taints
kubectl describe nodes node-pool-redis-01 node-pool-redis-02
```

## Debug and dry run before touching production

`--debug --dry-run` shows exactly what Helm intends to change, create, or delete, StatefulSet spec, ConfigMaps, service accounts, pod disruption budgets, before any of it happens:

```bash
# Run upgrade with debug to see detailed execution plans
helm upgrade redis-production bitnami/redis \
  --values current-values.yaml \
  --version 17.3.8 \
  --debug \
  --dry-run > upgrade-plan.log
```

Read the output for changes that affect scheduling. A chart bump between major versions can silently change how pods get placed, for example switching from a plain `nodeSelector` to a `nodeAffinity` block:

```yaml
# Previous StatefulSet template (truncated)
nodeSelector:
  redis-workload: "true"

# New StatefulSet template in debug output
nodeAffinity:
  requiredDuringSchedulingIgnoredDuringExecution:
    nodeSelectorTerms:
    - matchExpressions:
      - key: redis-workload
        operator: In
        values:
        - "true"
```

If the upgrade needs to migrate pods to different nodes at the same time, dry-run that combination explicitly before running it for real:

```bash
# Test with node migration settings added
helm upgrade redis-production bitnami/redis \
  --values current-values.yaml \
  --set master.nodeSelector."kubernetes\.io/hostname"=node-pool-redis-03 \
  --set replica.nodeSelector."kubernetes\.io/hostname"=node-pool-redis-04 \
  --version 17.3.8 \
  --dry-run
```

Confirm the plan does what you expect: a new master on the target node, replicas migrating gradually, PersistentVolumeClaims preserved.

## Executing the upgrade

Back up first, and confirm the target nodes are actually ready:

```bash
# Backup Redis data
kubectl exec -it redis-production-master-0 -- redis-cli SAVE

# Verify new target nodes are ready
kubectl get nodes node-pool-redis-03 node-pool-redis-04 -o wide
```

Put the node migration settings into a values file rather than a long `--set` chain:

```yaml
# redis-upgrade.yaml
master:
  nodeSelector:
    kubernetes.io/hostname: node-pool-redis-03
replica:
  nodeSelector:
    kubernetes.io/hostname: node-pool-redis-04
```

Then run the upgrade with the team watching:

```bash
# The actual upgrade command
helm upgrade redis-production bitnami/redis \
  --values current-values.yaml \
  --values redis-upgrade.yaml \
  --version 17.3.8 \
  --timeout 15m
```

Watch both the pod migration and Redis's own view of replication:

```bash
# Watch pods migrate across nodes
kubectl get pods -l app.kubernetes.io/name=redis -o wide -w

# Monitor Redis replication status
kubectl exec -it redis-production-master-0 -- redis-cli -a $REDIS_PASSWORD info replication
```

Pods should terminate on the old nodes and come up on the new ones while the minimum available replica count holds throughout.

## The rollback plan

Decide the rollback triggers before you need them, not during the incident:

```bash
# Keep history of revisions
helm history redis-production

# Prepare rollback command (if needed)
# helm rollback redis-production 3 --timeout 10m
```

Write down what would trigger it: replication lag past 30 seconds, application error rate above baseline, or new pods failing health checks for more than five minutes.

## Verifying success

```bash
# Document final state
helm status redis-production > post-upgrade-status.txt

# Verify Redis version
kubectl exec -it redis-production-master-0 -- redis-cli -a $REDIS_PASSWORD info server | grep redis_version
```

## The principle

The `--debug --dry-run` output is the part most teams skip, and it's the part that catches scheduling changes a version bump introduces silently. Combined with node selectors for the migration and a version-tagged rollback plan, the upgrade becomes routine instead of a 3 AM page.
</content>
