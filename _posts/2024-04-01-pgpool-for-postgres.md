---
layout: post
title: "Pgpool-II: Middleware for PostgreSQL"
description: "Pgpool-II sits between PostgreSQL and its clients as a connection pooler and load balancer, and this covers the Kubernetes setup that keeps writes consistent."
date:   2024-04-01 14:41:26 +0100
categories: [Database]
tags: [postgresql, kubernetes, devops]
---

<audio controls preload="metadata" src="/assets/audio/pgpool-for-postgres-summary.ogg">
  Your browser does not support the audio element.
</audio>


Pgpool-II is middleware that sits between PostgreSQL servers and a PostgreSQL client. It earns its keep when PostgreSQL can't handle the number of concurrent connections you're throwing at it directly: Pgpool-II pools and load-balances those connections across your database servers instead.

For more information, you can visit the official repository: [Pgpool-II on Kubernetes](https://github.com/pgpool/pgpool2_on_k8s).

## Installation

To set up Pgpool-II, follow these commands:

1. Download the configuration and deployment YAML files:
   ```shell
   curl -LO https://raw.githubusercontent.com/pgpool/pgpool2_on_k8s/master/pgpool-configmap.yaml
   curl -LO https://raw.githubusercontent.com/pgpool/pgpool2_on_k8s/master/pgpool-deploy.yaml
   ```

2. Apply the configuration and deployment using `kubectl`:
   ```shell
   kubectl apply -f pgpool-configmap.yaml
   kubectl apply -f pgpool-deploy.yaml
   ```

## Configuration Enhancements

We have made the following changes to the configuration:

- **Resource Allocation**: Adjusted CPU and memory limits and requests for optimal performance.
  ```yaml
  resources:
    limits:
      cpu: 0.5
      memory: 500Mi
    requests:
      cpu: 1
      memory: 100Mi
  ```

- **Liveness and Readiness Probes**: Ensured that the pod can be restarted when Pgpool-II is not functioning and that it won’t receive requests before it's ready.
  ```yaml
  livenessProbe:
    exec:
      command:
        - bash
        - -ec
        - PG_PASSWORD=$DB_PASSWORD psql -U postgres -h localhost -p 9999 -c SELECT 1
    timeoutSeconds: 2
    initialDelaySeconds: 20
    periodSeconds: 5
    successThreshold: 1
    failureThreshold: 2

  readinessProbe:
    exec:
      command:
        - bash
        - -ec
        - PG_PASSWORD=$DB_PASSWORD psql -U postgres -h localhost -p 9999 -c SELECT 1
    timeoutSeconds: 2
    initialDelaySeconds: 20
    periodSeconds: 5
    successThreshold: 1
    failureThreshold: 3
  ```

## Write Operation Handling

We have configured Pgpool-II to always disable load balancing on write operations with the following setting:
```ini
disable_load_balance_on_write = always
```
This ensures that after a write operation, all subsequent read operations are directed to the primary server instead of a standby. That matters because there is often a slight delay as the standby catches up with the WAL logs from the primary; a query directed to a standby that hasn't yet applied the change will not reflect the recent write.

For example:
```sql
BEGIN;
UPDATE goods SET price = price + 1.0 WHERE name = 'chair';
SELECT average(price) FROM goods WHERE type = 'furniture';
COMMIT;
```
In this scenario, the second `SELECT` statement will not retrieve the correct average price from the standby server if load balancing is enabled during write operations.
