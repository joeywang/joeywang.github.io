---
layout: post
title: "Zero-downtime GKE upgrades with PostgreSQL failover"
description: "Blue/green node pools plus a Kubegres replica promotion let you upgrade a GKE cluster, PostgreSQL included, without a maintenance window."
tags: [kubernetes, gcp, postgresql, devops, database]
categories: [DevOps]
date: 2025-12-29
---

<audio controls preload="metadata" src="/assets/audio/kube-node-upgrade-summary.ogg">
  Your browser does not support the audio element.
</audio>

Upgrading Kubernetes without downtime sounds simple in theory, but with stateful workloads in the mix it's one of the harder operational problems a DevOps team faces. This walks through near-zero-downtime upgrades on GKE, stateless services and PostgreSQL running inside the cluster both included, based on patterns actually run in production rather than idealized diagrams.

## Why "zero downtime" is hard

A Kubernetes upgrade touches the control plane, node OS and kubelet, container runtime, networking, storage attach/detach, and workload rescheduling, all at once. Kubernetes is built for rolling updates, but nodes still drain, pods still restart, and stateful workloads still move disks. The realistic goal is no planned maintenance window and no user-visible outage, even if a client sees a brief connection retry along the way.

GKE helps: managed control-plane upgrades, surge upgrades for node pools, stable node pool labels, and fast persistent-disk attach/detach. None of that guarantees zero downtime on its own; you still need a strategy for moving workloads deliberately instead of letting Kubernetes evict them wherever it likes.

## The core strategy: blue/green node pools

Instead of upgrading nodes in place, create two node pools: blue running the current Kubernetes version, green running the target one. Then move workloads from blue to green on your own terms. This avoids mass eviction, makes rollback as simple as moving workloads back, and gives you full control over which pods move first, which matters most for the database.

## Stateless workloads

This part is easy: at least two replicas, a PodDisruptionBudget, traffic through a Service or Ingress, and an application that tolerates pod restarts. Create the green pool, enable surge upgrades, drain blue nodes gradually, let Kubernetes reschedule pods onto green, then remove the old nodes. With correct PDBs, traffic never drops.

## The real challenge: PostgreSQL

A single-pod database can't be upgraded with zero downtime; the process has to stop and restart somewhere. Getting close to zero downtime needs replication, failover, and a stable service endpoint that always points at the current primary. Kubegres provides exactly that: one primary, one or more replicas, and controlled promotion during failover.

The high-level sequence:

1. Create the green node pool running the target Kubernetes version.
2. Force PostgreSQL pods to schedule only on green via node affinity on `cloud.google.com/gke-nodepool=green`.
3. Delete the replica pod. It restarts on green and re-syncs from the primary, with no client impact.
4. Promote the replica: Kubegres flips it to primary, the Service switches automatically, and clients reconnect.
5. Delete the old primary pod. It comes back as a replica on green and replication resumes.

At no point is the database unavailable, only a brief connection blip during promotion that a properly retrying application absorbs.

Be precise about what "zero downtime" means here: during promotion, existing connections may drop and a new write may fail briefly, but a client that retries succeeds. That's not a maintenance window, and users don't see an outage. It is the standard most teams mean when they say zero downtime.

## Common mistakes

* Upgrading node pools before the control plane
* No PodDisruptionBudgets
* Single-instance databases with no replica to promote
* Applications connecting to Pod IPs instead of Services
* No retry logic in the database client
* Zonal disks in a multi-zone cluster, unplanned

## When Kubernetes is the wrong place for the database

Even executed well, running a database in Kubernetes adds operational surface. If the requirement is strict zero downtime with minimal operational overhead and a hard SLA, Cloud SQL or AlloyDB is probably the better call. Kubernetes-hosted databases make sense when you already operate HA databases, want portability, and accept the infrastructure-level responsibility that comes with it.

Zero-downtime upgrades aren't magic: they come from classifying workloads correctly, running blue/green infrastructure, controlling scheduling explicitly, and building applications that tolerate failure. GKE gives you the building blocks; treating the upgrade as a controlled migration rather than a button click is what makes it routine.
