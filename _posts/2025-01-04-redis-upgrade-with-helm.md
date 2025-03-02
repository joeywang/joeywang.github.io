---
layout: post
title: "A DevOps Journey: Smoothly Upgrading Bitnami Redis Helm Charts"
date: "2025-01-04"
categories: [devops, redis, helm]
---

# A DevOps Journey: Smoothly Upgrading Bitnami Redis Helm Charts

## The 3 AM Incident

It was 3 AM when Sarah's phone buzzed with alerts. The Redis cluster had crashed during what should have been a routine upgrade. As the team's DevOps engineer, she spent the next four hours restoring service and recovering data. "Never again," she promised herself.

This is a story about preventing that 3 AM call—about upgrading Redis in Kubernetes the right way.

## Understanding the Challenge

Redis often serves as the beating heart of production systems—handling caching, session management, and real-time data processing. When deployed via Bitnami's Helm charts in Kubernetes, upgrading requires surgical precision.

Our challenge goes beyond a simple version bump: we need to migrate Redis pods across nodes in our Kubernetes cluster while ensuring data integrity and minimal downtime.

## Preparation: The Foundation of Success

### Day 1: Reconnaissance

Sarah begins her upgrade planning with a thorough assessment:

```bash
# Update the chart repository information
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Check available versions and release dates
helm search repo bitnami/redis --versions
```

She sees several versions available, noting the changelog between her current 16.x version and the target 17.x release.

### Day 2: Mapping the Current Deployment

```bash
# Export current values for review
helm get values redis-production > current-values.yaml

# Examine the deployment history
helm history redis-production
```

The history reveals the journey of their Redis deployment:

```
REVISION    UPDATED                     STATUS        CHART            APP VERSION    DESCRIPTION
1           Thu Mar 10 11:13:22 2024    superseded    redis-16.8.5     6.2.7          Install complete
2           Fri Apr 14 15:42:19 2024    superseded    redis-16.12.3    6.2.7          Configuration update
3           Mon Jul 17 09:05:43 2024    deployed      redis-16.13.1    6.2.7          Scaled replicas
```

### Day 3: Understanding Node Placement

Our Redis pods are running on specific nodes that need maintenance. Sarah examines the current placement:

```bash
# Check which nodes are running Redis pods
kubectl get pods -l app.kubernetes.io/name=redis -o wide

# Review node labels and taints
kubectl describe nodes node-pool-redis-01 node-pool-redis-02
```

She discovers that their Redis master runs on `node-pool-redis-01` and replicas on `node-pool-redis-02`. Both nodes are scheduled for kernel updates next week.

## The Upgrade Plan: Detailed Evaluation with Debug Tools

### Debug Mode: Seeing Behind the Curtain

Sarah knows that understanding the exact changes Helm will make is crucial:

```bash
# Run upgrade with debug to see detailed execution plans
helm upgrade redis-production bitnami/redis \
  --values current-values.yaml \
  --version 17.3.8 \
  --debug \
  --dry-run > upgrade-plan.log
```

The `--debug` flag reveals every resource that Helm would modify, create, or delete, including:
- Changes to StatefulSet specifications
- ConfigMap modifications with new Redis configurations
- Service account permissions
- Pod disruption budgets

Examining `upgrade-plan.log`, she notices critical changes in the pod template that would affect scheduling:

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

### Dry Run: Verifying the Plan

With initial debug information in hand, Sarah performs a focused dry run to verify specific aspects:

```bash
# Test with node migration settings added
helm upgrade redis-production bitnami/redis \
  --values current-values.yaml \
  --set master.nodeSelector."kubernetes\.io/hostname"=node-pool-redis-03 \
  --set replica.nodeSelector."kubernetes\.io/hostname"=node-pool-redis-04 \
  --version 17.3.8 \
  --dry-run
```

The dry run confirms that the upgrade would:
1. Create new Redis master pod on `node-pool-redis-03`
2. Gradually migrate replicas to `node-pool-redis-04`
3. Preserve the PersistentVolumeClaims

## The Upgrade Day: Executing with Confidence

### Morning: Final Preparations

```bash
# Backup Redis data
kubectl exec -it redis-production-master-0 -- redis-cli SAVE

# Verify new target nodes are ready
kubectl get nodes node-pool-redis-03 node-pool-redis-04 -o wide
```

Sarah then creates a custom values file that includes the node migration settings:

```yaml
# redis-upgrade.yaml
master:
  nodeSelector:
    kubernetes.io/hostname: node-pool-redis-03
replica:
  nodeSelector:
    kubernetes.io/hostname: node-pool-redis-04
```

### Noon: The Upgrade Window

With team members on standby, Sarah initiates the upgrade:

```bash
# The actual upgrade command
helm upgrade redis-production bitnami/redis \
  --values current-values.yaml \
  --values redis-upgrade.yaml \
  --version 17.3.8 \
  --timeout 15m
```

She monitors the migration in real-time:

```bash
# Watch pods migrate across nodes
kubectl get pods -l app.kubernetes.io/name=redis -o wide -w

# Monitor Redis replication status
kubectl exec -it redis-production-master-0 -- redis-cli -a $REDIS_PASSWORD info replication
```

The output shows pods terminating on old nodes and creating on the target nodes, maintaining the required minimum available replicas throughout the process.

## The Rollback Safety Net

Despite careful planning, Sarah knows that production systems require rollback preparation:

```bash
# Keep history of revisions
helm history redis-production

# Prepare rollback command (if needed)
# helm rollback redis-production 3 --timeout 10m
```

She documents this rollback plan for the team, with specific indicators that would trigger execution:
- If replication lag exceeds 30 seconds
- If application errors increase above baseline
- If new pods fail health checks after 5 minutes

## Success and Learnings

The upgrade completes successfully. All Redis pods now run on the new nodes with the updated version. Sarah documents the journey:

```bash
# Document final state
helm status redis-production > post-upgrade-status.txt

# Verify Redis version
kubectl exec -it redis-production-master-0 -- redis-cli -a $REDIS_PASSWORD info server | grep redis_version
```

## Key Takeaways for Your Redis Upgrade Journey

1. **Use Debug Mode Strategically**: The `--debug` flag reveals resource changes that might otherwise be missed in planning.

2. **Validate with Dry Runs**: Multiple `--dry-run` tests with different parameters help identify potential issues.

3. **Plan for Node Migration**: Use node selectors or pod affinity rules to control where Redis pods land.

4. **Monitor the Right Metrics**: Watch both Kubernetes pod states and Redis-specific metrics during migration.

5. **Keep History for Rollbacks**: Helm's history feature provides a crucial safety net for complex upgrades.

6. **Document Everything**: Each step of the journey provides learnings for future upgrades.

By following Sarah's methodical approach, you can upgrade your Redis deployment while seamlessly migrating pods across nodes—all without getting that dreaded 3 AM call.
