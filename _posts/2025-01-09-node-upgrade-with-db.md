---
layout: post
title: "Kubernetes Node Upgrade Procedure: Best Practices and Failover Mechanisms"
date: "2025-01-09"
categories: k8s node upgrade database
---

# Kubernetes Node Upgrade Procedure: Best Practices and Failover Mechanisms

When managing a Kubernetes cluster, node upgrades are an inevitable part of the maintenance cycle. Whether you're applying security patches, upgrading the Kubernetes version, or implementing system updates, a well-planned node upgrade procedure ensures minimal disruption to your workloads. This article outlines a comprehensive approach to node upgrades and explores the various hooks and mechanisms available for implementing effective failover strategies.

## Understanding Node Upgrades

A node upgrade typically involves:

1. Cordoning the node to prevent new pod scheduling
2. Draining the node to gracefully evict existing pods
3. Performing the actual upgrade (OS patches, kubernetes components, etc.)
4. Uncordoning the node to return it to service

## Best Practices for Node Upgrades

### Pre-Upgrade Planning

- **Inventory Assessment**: Document all workloads running on the node
- **Impact Analysis**: Identify critical applications that might be affected
- **Backup Strategy**: Ensure all critical data is backed up
- **Communication Plan**: Notify stakeholders about the maintenance window

### Execution Strategy

#### 1. Node Preparation

```bash
# Mark the node as unschedulable
kubectl cordon <node-name>

# Check node status
kubectl get nodes
```

#### 2. Controlled Pod Eviction

```bash
# Drain the node with graceful termination
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

#### 3. Upgrade Process

- Apply OS updates
- Upgrade kubelet, kube-proxy, and container runtime
- Apply any node-specific configurations

#### 4. Verification

```bash
# Verify node status after upgrade
kubectl get nodes -o wide

# Check component versions
kubectl get nodes <node-name> -o jsonpath='{.status.nodeInfo.kubeletVersion}'
```

#### 5. Return to Service

```bash
# Mark the node as schedulable again
kubectl uncordon <node-name>
```

## Failover Mechanisms and Hooks

Kubernetes provides several mechanisms to ensure application resilience during node upgrades:

### 1. Pod Disruption Budgets (PDBs)

PDBs allow you to limit the number of pods that can be down simultaneously during voluntary disruptions like node drains.

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2  # or maxUnavailable: 1
  selector:
    matchLabels:
      app: my-application
```

### 2. PriorityClasses

PriorityClasses determine the order of pod eviction during resource constraints or node drains.

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority-service
spec:
  value: 1000000
  globalDefault: false
  description: "High priority pods that should be evicted last"
```

### 3. Pod Lifecycle Hooks

These hooks enable applications to gracefully handle termination:

- **PreStop Hook**: Executed immediately before a pod is terminated
  ```yaml
  lifecycle:
    preStop:
      exec:
        command: ["/bin/sh", "-c", "/pre-stop-hook.sh"]
  ```

- **PostStart Hook**: Executed immediately after a container is created
  ```yaml
  lifecycle:
    postStart:
      exec:
        command: ["/bin/sh", "-c", "/post-start-hook.sh"]
  ```

### 4. Termination Grace Period

Defines how long Kubernetes waits for a pod to shut down gracefully before force terminating it.

```yaml
terminationGracePeriodSeconds: 60
```

### 5. Readiness Probes

Ensure traffic is only sent to pods that are ready to handle requests.

```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 5
```

### 6. StatefulSet Ordered Updates

For stateful applications, StatefulSets provide ordered and graceful deployment updates:

```yaml
spec:
  updateStrategy:
    type: RollingUpdate
    rollingUpdate:
      partition: 0
```

### 7. Custom Controllers and Operators

Application-specific operators (like for databases) often implement custom failover logic:

- **Database Operators**: Kubegres, PostgreSQL Operator, MySQL Operator
- **Service Mesh Controllers**: Istio, Linkerd for traffic management
- **Custom Resource Definitions (CRDs)**: Extending Kubernetes API for application-specific failover behaviors

### 8. Anti-Affinity Rules

Ensure pods are distributed across different nodes to minimize impact:

```yaml
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
    - labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values:
          - database
      topologyKey: "kubernetes.io/hostname"
```

## Real-World Example: Database Failover During Node Upgrade

For database applications like PostgreSQL managed by Kubegres, a comprehensive failover strategy might combine:

1. **High Priority Class**: Ensuring database pods are evicted last
2. **Pod Disruption Budget**: Maintaining minimum database replicas
3. **PreStop Hooks**: Triggering clean database shutdown
4. **StatefulSet Ordered Updates**: Controlling the order of pod restarts
5. **Anti-Affinity Rules**: Distributing replicas across nodes
6. **Custom Operator Logic**: Handling leader election and promotion

## Conclusion

A successful node upgrade procedure requires careful planning and leveraging of Kubernetes' built-in mechanisms for failover and high availability. By implementing the appropriate hooks and strategies, you can maintain application availability even during infrastructure maintenance operations.

The key to minimal disruption lies in understanding your workloads' specific requirements and applying the right combination of priority settings, lifecycle hooks, and resource definitions. With proper preparation, even critical stateful applications can remain highly available during node upgrades.
