---
layout: page
title: Migrate GCP Classic Load Balancer
permalink: /migrate-gcp-classic-load-balancer/
date: 2025-08-09
categories: [ gcp ]
tags: [ gcp, load balancer ]
---

## The Essential Guide to Migrating Your GCP Classic Load Balancer to the Global External Load Balancer

The Global External Application Load Balancer is the latest evolution of Google Cloud's Layer 7 load balancing service. It provides a modern control plane with enhanced traffic management, security, and global reach. If your applications are still running behind a **Classic Application Load Balancer**, it's time to upgrade to take advantage of these new capabilities. This guide provides a step-by-step walkthrough of the migration process using the `gcloud` command-line tool, following a safe, staged approach to ensure zero downtime.

-----

### Understanding the Migration Strategy

The migration process is a managed operation handled by GCP. It's designed to be non-disruptive, allowing you to gracefully shift traffic from the old infrastructure to the new. The core strategy involves a two-part phased migration:

1.  **Backend Service Migration:** This prepares your backend resources (like Managed Instance Groups or NEGs) to serve traffic from the new load balancer infrastructure.
2.  **Forwarding Rule Migration:** This updates the frontend, which handles incoming traffic, to use the new control plane.

For each of these steps, you'll progress through four distinct states: `PREPARE`, `TEST_BY_PERCENTAGE`, `TEST_ALL_TRAFFIC`, and `MIGRATE`. This staged approach gives you full control and allows for testing at each stage.

-----

### Step 1: Upgrade the Backend Service

This phase prepares your backend infrastructure to be compatible with the new load balancer. The `gcloud beta compute backend-services update` command is used for this entire process.

#### a. Prepare the Backend

This command places the backend service in a state where it can start accepting traffic from the new load balancer without changing the current traffic flow.

```bash
gcloud beta compute backend-services update [BACKEND_SERVICE_NAME] \
--external-managed-migration-state=PREPARE \
--global
```

#### b. Test with a Percentage of Traffic

Once the backend is prepared, you can begin sending a small, controlled amount of traffic to the new infrastructure. This lets you monitor performance and logs to ensure there are no issues.

```bash
gcloud beta compute backend-services update [BACKEND_SERVICE_NAME] \
--external-managed-migration-state=TEST_BY_PERCENTAGE \
--external-managed-migration-testing-percentage=10 \
--global
```

You can increase the `--external-managed-migration-testing-percentage` as you gain confidence.

#### c. Test with All Traffic

After successful testing with a percentage of traffic, you can route all traffic through the new load balancer's infrastructure. The backend service is now fully migrated, but the forwarding rule is not yet updated.

```bash
gcloud beta compute backend-services update [BACKEND_SERVICE_NAME] \
--external-managed-migration-state=TEST_ALL_TRAFFIC \
--global
```

#### d. Complete Backend Migration

The final step for the backend service is to permanently set its load balancing scheme to the new `EXTERNAL_MANAGED` type.

```bash
gcloud beta compute backend-services update [BACKEND_SERVICE_NAME] \
--external-managed-migration-state=MIGRATE \
--global
```

-----

### Step 2: Upgrade the Forwarding Rule

With the backend successfully migrated, the next step is to update the frontend forwarding rule to use the new infrastructure. This is also a staged process, mirroring the steps for the backend. Use the `gcloud beta compute forwarding-rules update` command for this.

#### a. Prepare the Forwarding Rule

```bash
gcloud beta compute forwarding-rules update [FORWARDING_RULE_NAME] \
--external-managed-migration-state=PREPARE \
--global
```

#### b. Test with a Percentage of Traffic

```bash
gcloud beta compute forwarding-rules update [FORWARDING_RULE_NAME] \
--external-managed-migration-state=TEST_BY_PERCENTAGE \
--external-managed-migration-testing-percentage=10 \
--global
```

#### c. Test with All Traffic

```bash
gcloud beta compute forwarding-rules update [FORWARDING_RULE_NAME] \
--external-managed-migration-state=TEST_ALL_TRAFFIC \
--global
```

#### d. Complete Forwarding Rule Migration

This final command updates the forwarding rule's load balancing scheme to the `EXTERNAL_MANAGED` type, completing the full migration.

```bash
gcloud beta compute forwarding-rules update [FORWARDING_RULE_NAME] \
--external-managed-migration-state=MIGRATE \
--global
```

-----

### The Importance of Rollback ↩️

GCP's managed migration process includes a built-in **rollback** capability, which is crucial for safety. If you encounter any issues during the migration, you can revert the state.

  * To roll back to the previous state, you would use the same `update` command but change the `--external-managed-migration-state` flag to the desired prior state. For example, to revert from `TEST_ALL_TRAFFIC` back to `TEST_BY_PERCENTAGE`:

    ```bash
    gcloud beta compute forwarding-rules update [FORWARDING_RULE_NAME] \
    --external-managed-migration-state=TEST_BY_PERCENTAGE \
    --external-managed-migration-testing-percentage=50 \
    --global
    ```

  * For a full rollback to the classic load balancer, you would change the load balancing scheme of the forwarding rule back to `EXTERNAL`. The rollback functionality is available for a limited time (90 days) after the migration is completed.

By following this controlled, staged process, you can upgrade your load balancer with confidence, unlocking a new level of performance and features while minimizing any risk to your application's availability.
