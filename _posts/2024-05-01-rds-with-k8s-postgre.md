---
layout: post
title:  "Scaling PostgreSQL on Kubernetes with Kubegres"
description: "How Kubegres brings primary/standby failover, automatic backups, and PITR to a self-hosted PostgreSQL cluster on Kubernetes without a managed database bill."
date:   2024-05-01 14:41:26 +0100
categories: [Database]
tags: [postgresql, kubernetes, devops, database]
pin: true
---

<audio controls preload="metadata" src="/assets/audio/rds-with-k8s-postgre-summary.ogg">
  Your browser does not support the audio element.
</audio>


Running PostgreSQL yourself on a VM works until you need real availability. Our setup was Postgres 13.1 on a single GCP VM, with daily exports to a storage bucket and weekly base backups plus WAL for point-in-time recovery. Disaster recovery from that setup took up to two hours: rebuild the VM, restore the base backup, replay the WAL. Two hours of downtime is hard to explain to customers, and the VM itself was a single point of failure the whole time.

Kubegres is a Kubernetes operator for PostgreSQL that gets you a primary/standby cluster without paying for a managed service like RDS or Cloud SQL. It handles the parts that make self-hosted Postgres risky: failover, replication, and backups.

## What Kubegres gives you

- **Primary/standby out of the box**: if a node in the GKE cluster goes down, the cluster keeps serving.
- **Automatic failover**: a standby takes over as primary within seconds, without manual intervention.
- **Lifecycle management**: Kubegres owns the PVCs, services, and StatefulSet for you.
- **Backups and PITR**: daily backups run as Kubernetes Jobs, with point-in-time recovery built in.

## Deploying it

Install the operator:

```
kubectl apply -f https://raw.githubusercontent.com/reactive-tech/kubegres/v1.12/kubegres.yaml
```

Create the password secret:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: default
type: Opaque
stringData:
  superUserPassword: postgresSuperUserPsw
  replicationUserPassword: postgresReplicaPsw
```

Create the cluster:

```yaml
apiVersion: kubegres.reactive-tech.io/v1
kind: Kubegres
metadata:
  name: postgres
  namespace: default
spec:
  replicas: 3
  image: postgres:13.2
  database:
    size: 200Mi
  env:
    - name: POSTGRES_PASSWORD
      valueFrom:
        secretKeyRef:
          name: postgres-secret
          key: superUserPassword
    - name: POSTGRES_REPLICATION_PASSWORD
      valueFrom:
        secretKeyRef:
          name: postgres-secret
          key: replicationUserPassword
```

Kubegres creates the PVCs, services, and a StatefulSet with three PostgreSQL instances from that spec.

## Migrating with minimal downtime

1. Stand up the Kubegres cluster as above, but reduced to a single primary instance.
2. Point Pgpool-II (already in front of the old VM-based Postgres) at the existing VM as primary.
3. Route the application to the Pgpool-II service instead of talking to the VM directly.
4. At low-traffic time, repoint Pgpool-II's configuration at the Kubegres primary.
5. Promote the Kubegres instance to primary.
6. Scale the Kubegres cluster back up to three or more replicas.

The application keeps serving requests through the whole migration; only the target behind Pgpool-II changes.

## Scaling and upkeep

Scaling out is a one-line change: bump `replicas` in the manifest and apply it. Kubegres spins up the new standbys and handles replication itself.

What it doesn't do for you: alerting on the metrics that matter, testing your disaster recovery plan against a real failure, and keeping Kubegres and Postgres versions current. Those stay on you.
