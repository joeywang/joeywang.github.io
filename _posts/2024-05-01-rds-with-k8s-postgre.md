---
layout: post
title:  "Scaling PostgreSQL on Kubernetes with Kubegres"
date:   2024-05-01 14:41:26 +0100
categories: PostgreSQL
pin: true
---

# Scaling PostgreSQL on Kubernetes with Kubegres

## Introduction

As a small company or startup, managing a relational database like PostgreSQL can be challenging, especially when it comes to ensuring high availability, scalability, and cost-effectiveness. While services like Amazon RDS (Relational Database Service) or Google Cloud SQL offer attractive solutions, the associated costs can be prohibitive for smaller organizations.

To address this, we can turn to open-source projects that provide a homemade version of a managed database service. In this article, we'll explore one such solution: Kubegres, a Kubernetes operator for deploying and managing PostgreSQL clusters.

## Current Challenges

Your current setup involves running a PostgreSQL 13.1 instance on a Google Cloud Platform (GCP) VM, with daily database exports to GCP storage buckets and weekly base backups with Write-Ahead Logs (WAL) for Point-In-Time Recovery (PITR). While this solution provides some level of reliability, it also comes with significant drawbacks:

- **Expensive and Time-Consuming Disaster Recovery**: The process of rebuilding the VM, recovering the database from the base backup, and restoring the data using PITR can take up to 2 hours, which is unacceptable for your customers.
- **Lack of High Availability**: The stability of the GCP VM is a single point of failure, and any downtime can significantly impact your service.

## Introducing Kubegres

To address these challenges, you've decided to explore the use of Kubegres, a Kubernetes operator for PostgreSQL. Kubegres offers several benefits that can improve the reliability and manageability of your PostgreSQL deployment:

1. **High Availability**: Kubegres provides a built-in primary/standby setup, ensuring zero downtime even when nodes in your GKE (Google Kubernetes Engine) cluster go down.
2. **Automatic Failover**: Kubegres automatically manages the failover process, allowing the standby instance to take over as the primary within seconds if the primary instance fails.
3. **Simplified Management**: Kubegres handles the complex tasks of managing the lifecycle and data replication of PostgreSQL instances within a Kubernetes environment.
4. **Backups and Disaster Recovery**: Kubegres integrates daily backups using Kubernetes Jobs and supports PITR, making it easier to recover from data loss or corruption.

## Deploying Kubegres

To set up your Kubegres cluster, follow these steps:

1. Install the Kubegres operator:
   ```
   kubectl apply -f https://raw.githubusercontent.com/reactive-tech/kubegres/v1.12/kubegres.yaml
   ```
2. Create a secret resource for storing the PostgreSQL passwords:
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
3. Create a Kubegres cluster:
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

Kubegres will create the necessary resources, including PersistentVolumeClaims (PVCs), Services, and a StatefulSet with 3 PostgreSQL instances.

## Migration Plan

To migrate your existing PostgreSQL service to the new Kubegres-based solution, follow these steps:

1. Set up the Kubegres cluster as described above.
2. Reduce the Kubegres cluster to a single primary instance.
3. Configure PgPool-II to act as a load balancer, pointing it to your existing VM-based PostgreSQL instance as the primary.
4. Update your application to connect to the PgPool-II service instead of the VM-based PostgreSQL instance.
5. At a time with minimal user activity, change the PgPool-II configuration to point to the primary instance in the Kubegres cluster.
6. Promote the Kubegres primary instance to become the new primary.
7. Expand the Kubegres cluster by increasing the number of replicas to 3 or more.

This approach allows you to migrate your service with minimal downtime, as the application continues to serve users throughout the process.

## Scalability and Expansion

As your user base grows, you can easily scale the Kubegres cluster by modifying the `replicas` field in the Kubegres manifest and applying the changes. Kubegres will automatically spin up new standby instances and handle the replication process.

## Monitoring and Maintenance

To ensure the health and reliability of your Kubegres-based PostgreSQL deployment, you should implement monitoring and maintenance practices, such as:

- Configuring alerting and monitoring tools to track key metrics and events.
- Regularly reviewing backup and recovery procedures, and testing the disaster recovery plan.
- Staying up-to-date with Kubegres and PostgreSQL version updates to apply security patches and benefit from new features.

## Conclusion

By leveraging Kubegres, you can create a highly available, scalable, and cost-effective PostgreSQL solution on Kubernetes. The simplified management, automatic failover, and built-in backup and recovery features of Kubegres can help you overcome the challenges of your current setup and provide a more reliable service for your customers.

As you continue to expand and grow your business, the flexibility and scalability of the Kubegres-based solution will be a valuable asset, allowing you to adapt to changing requirements and ensure the long-term success of your PostgreSQL deployment.
