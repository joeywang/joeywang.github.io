---
layout: page
title: Migrating a GCP Classic Load Balancer to Global External
description: "GCP lets you migrate a Classic Application Load Balancer to the Global External Load Balancer with a staged, four-state rollout that avoids downtime."
permalink: /migrate-gcp-classic-load-balancer/
date: 2025-08-09
categories: [DevOps]
tags: [gcp, load-balancer, networking, devops]
---

<audio controls preload="metadata" src="/assets/audio/migrate-gcp-load-balancer-summary.ogg">
  Your browser does not support the audio element.
</audio>

If you're still running a **Classic Application Load Balancer** on GCP, moving to the Global External Application Load Balancer gets you a modern control plane with better traffic management, security, and global reach. GCP handles the migration itself, and it's designed to be non-disruptive: you shift traffic from the old infrastructure to the new one in stages, with a rollback available at every step. This is the `gcloud` walkthrough for doing that safely.

-----

### The Two-Part Migration

The migration has two parts, run in order:

1.  **Backend service migration:** prepares your backend resources (Managed Instance Groups or NEGs) to serve traffic from the new load balancer infrastructure.
2.  **Forwarding rule migration:** updates the frontend, the part that handles incoming traffic, to use the new control plane.

Each part moves through the same four states: `PREPARE`, `TEST_BY_PERCENTAGE`, `TEST_ALL_TRAFFIC`, and `MIGRATE`.

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

### Rolling Back

GCP's managed migration process includes a built-in rollback for each stage. If you see problems during the migration, you can revert to the prior state instead of pushing forward.

  * To roll back, use the same `update` command but change the `--external-managed-migration-state` flag to the desired prior state. For example, to revert from `TEST_ALL_TRAFFIC` back to `TEST_BY_PERCENTAGE`:

    ```bash
    gcloud beta compute forwarding-rules update [FORWARDING_RULE_NAME] \
    --external-managed-migration-state=TEST_BY_PERCENTAGE \
    --external-managed-migration-testing-percentage=50 \
    --global
    ```

  * For a full rollback to the classic load balancer, change the load balancing scheme of the forwarding rule back to `EXTERNAL`. This is only available for 90 days after the migration completes, so don't let a "we'll clean it up later" backend or forwarding rule sit in `MIGRATE` state indefinitely.

The staged states exist because backend migration and forwarding rule migration are two separate blast radii: you can validate the backend under real traffic before you ever touch the frontend that clients connect to. That separation is the whole reason this process is safe to run against production.
