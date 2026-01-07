---
layout: post
title: "Zero-Downtime Kubernetes Upgrades on GCP: A Practical DevOps Guide"
description: A detailed guide on performing zero-downtime Kubernetes upgrades on GCP using GKE, focusing on both stateless services and PostgreSQL databases.
tags: [DevOps, GCP, GKE, Kubernetes, Zero-Downtime, PostgreSQL]
date: 2025-12-29
---

# Zero-Downtime Kubernetes Upgrades on GCP: A Practical DevOps Guide

**Upgrading Kubernetes without downtime** sounds simple in theory — but in production, especially with **stateful workloads**, it’s one of the hardest operational problems DevOps teams face.

This article walks through **how to perform near zero-downtime Kubernetes upgrades on Google Cloud Platform (GCP)** using **GKE**, including **stateless services and PostgreSQL running inside Kubernetes**. It’s based on real production patterns, not idealized diagrams.

---

## Why “Zero Downtime” Is Hard in Kubernetes

Kubernetes upgrades affect multiple layers at once:

* Control plane (API server, scheduler)
* Node OS + kubelet
* Container runtime
* Networking (kube-proxy, CNI)
* Storage attach/detach
* Workload rescheduling

Even if Kubernetes is designed for rolling updates, **nodes still drain**, **pods still restart**, and **stateful workloads still move disks**.

The goal, realistically, is:

> **No planned maintenance window and no user-visible outage**, even if brief connection retries occur.

---

## Why GKE Is a Good Platform for This

Google Kubernetes Engine (GKE) gives us several advantages:

* Managed control plane upgrades
* Surge upgrades for node pools
* Stable node pool labeling
* First-class support for multi-zone clusters
* Strong integration with persistent disks

But **GKE alone does not guarantee zero downtime** — you still need the right strategy.

---

## The Core Strategy: Blue/Green Node Pools

Instead of upgrading nodes in place, we create **two node pools**:

* **Blue**: current production nodes (Kubernetes 1.34)
* **Green**: new nodes (Kubernetes 1.35)

Then we **move workloads deliberately** from blue to green.

### Why this works

* No mass eviction
* Easy rollback (just move workloads back)
* Full control over *which pods move first*
* Especially powerful for databases

---

## Zero Downtime for Stateless Workloads

Stateless services are the easy part.

### Requirements

* At least **2 replicas**
* Proper **PodDisruptionBudgets**
* Traffic routed via **Services or Ingress**
* Applications tolerate pod restarts

### Flow

1. Create green node pool
2. Enable surge upgrades (or manual scheduling)
3. Drain blue nodes gradually
4. Kubernetes reschedules pods onto green
5. Old nodes are removed

With correct PDBs, traffic never drops.

---

## The Real Challenge: Stateful Workloads (PostgreSQL)

A **single-pod database cannot be upgraded with zero downtime** — the process must stop and restart somewhere.

To achieve near zero downtime, you need:

* **Replication**
* **Failover**
* **Stable service endpoints**

### Example: PostgreSQL with Kubegres

Kubegres provides:

* One primary
* One or more replicas
* A Service that always points to the primary
* Controlled promotion during failover

This makes zero-downtime upgrades *possible*.

---

## Zero-Downtime PostgreSQL Upgrade Pattern (Kubegres)

### High-level idea

1. Move the **replica** to green
2. Promote the replica on green to **primary**
3. Move the old primary (now replica) to green
4. Remove blue pool

At no point is the database unavailable — only a brief connection blip during promotion, which applications must retry.

---

### Step-by-Step Flow

#### 1. Create the green node pool

The new pool runs the target Kubernetes version (e.g. 1.35).

#### 2. Force PostgreSQL pods to schedule only on green

Using node affinity on:

```
cloud.google.com/gke-nodepool=green
```

This ensures any recreated pod lands on green.

#### 3. Move the replica first

Delete the replica pod:

* It restarts on green
* It re-syncs from the primary
* No client impact

#### 4. Promote the replica

Kubegres supports manual promotion:

* Replica becomes primary
* Service switches automatically
* Clients reconnect

#### 5. Move the old primary

Delete the old pod:

* It comes back as a replica on green
* Replication resumes

Now **both primary and replica are on green**, running on upgraded nodes.

---

## What “Zero Downtime” Really Means Here

Let’s be precise.

During PostgreSQL promotion:

* Existing connections may drop
* New writes may fail briefly
* Properly configured apps retry and succeed

This is **not a maintenance window**.
Users do not see an outage.

In modern DevOps terms, this is considered *zero downtime*.

---

## Key GKE Features That Make This Possible

### Surge Node Upgrades

Allow new nodes to come online before old ones drain.

### Node Pool Labels

Predictable scheduling using:

```
cloud.google.com/gke-nodepool
```

### Managed Control Plane

No API server downtime during upgrades.

### Persistent Disk Re-attachment

Fast attach/detach when pods move.

---

## Common Mistakes to Avoid

❌ Upgrading node pools before the control plane
❌ No PodDisruptionBudgets
❌ Single-instance databases
❌ Apps connecting to Pod IPs instead of Services
❌ No retry logic in DB clients
❌ Zonal disks in multi-zone clusters without planning

---

## When Kubernetes Is the Wrong Place for Databases

Even with perfect execution, running databases in Kubernetes adds complexity.

If your requirements are:

* Strict zero downtime
* Minimal operational overhead
* Strong SLAs

Then **Cloud SQL or AlloyDB** may be a better choice.

Kubernetes databases shine when:

* You already operate HA databases
* You want portability
* You accept infrastructure-level responsibility

---

## Final Thoughts

Zero-downtime upgrades are **not magic** — they are the result of:

* Careful workload classification
* Blue/green infrastructure
* Explicit control over scheduling
* Designing applications to tolerate failure

GKE gives you excellent building blocks, but **DevOps discipline** makes the difference.

If you treat upgrades as a controlled migration instead of a button click, **Kubernetes upgrades become routine instead of terrifying**.

