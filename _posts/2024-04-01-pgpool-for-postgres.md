---
layout: post
title:  "Pgpool-II: Middleware for PostgreSQL"
date:   2024-04-01 14:41:26 +0100
categories: PostgreSQL
---

# Pgpool-II: Middleware for PostgreSQL

Pgpool-II is a middleware solution that operates between PostgreSQL servers and a PostgreSQL database client. It is particularly useful for managing scenarios where PostgreSQL may not handle concurrent connections as efficiently as needed. In such cases, Pgpool-II serves as an effective load balancer between the application server and the database servers.

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
This ensures that after a write operation, all subsequent read operations are directed to the primary server instead of a standby. This is crucial because there may be a slight delay as the standby server catches up with the WAL logs from the primary. If a query is directed to a standby that has not yet applied the changes, it will not reflect the recent write operation.

For example:
```sql
BEGIN;
UPDATE goods SET price = price + 1.0 WHERE name = 'chair';
SELECT average(price) FROM goods WHERE type = 'furniture';
COMMIT;
```
In this scenario, the second `SELECT` statement will not retrieve the correct average price from the standby server if load balancing is enabled during write operations.
