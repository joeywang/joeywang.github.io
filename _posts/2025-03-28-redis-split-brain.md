---
title: "Redis Sentinel Split-Brain: A Midnight Nightmare"
date:   2025-03-28 14:41:26 +0100
categories: [Redis, Kubernetes]
tags: [Redis, Kubernetes, Sentinel, Split-Brain]
---
# Redis Sentinel Split-Brain: A Midnight Nightmare

Redis is a powerful in-memory data structure store, often used as a
database, cache, and message broker. However, when it comes to high
availability with Redis Sentinel, things can get a bit tricky. In this
post, we’ll explore the infamous "split-brain" scenario that can occur
with Redis Sentinel and how we tackled it head-on.

Imagine this: It's 2 AM, and suddenly, your phone buzzes relentlessly with alerts. Your Redis cluster, supposed to be rock-solid, is suddenly reporting inconsistent data. Panic sets in—welcome to the infamous "split-brain" scenario with Redis Sentinel.

### The Tale of Two Masters

Split-brain isn't just a catchy term. It's a frightening state where your Redis Sentinel cluster splits into factions due to network partitions or node failures. Each faction thinks the other has failed, electing its own Redis master independently. Before you know it, you've got multiple masters simultaneously accepting writes, creating inconsistencies and chaos in your data.

This problem often occurs during seemingly routine maintenance—such as Kubernetes node upgrades—where Redis pods are evicted, causing temporary but critical disruptions.

### Redis Sentinel—Guardian or Trouble-maker?

Redis Sentinel is supposed to prevent downtime by automatically detecting failures and electing a new master swiftly. Ironically, this automation can sometimes be the very source of split-brain headaches. The root causes usually boil down to aggressive timeout configurations, simultaneous pod termination, or overly sensitive network settings.

### How We Beat the Split-Brain Monster

At first, enabling regular Redis backups seemed like a good bandage—a reliable safety net for quick recovery. And indeed, regular snapshots (RDB or AOF) provide an excellent recovery mechanism. But we quickly learned backups don't prevent split-brain—they only help pick up the pieces afterward.

We needed a robust preventive solution. Here’s how we effectively tackled split-brain:

#### Step 1: Adjust Redis Sentinel Configuration

We tuned Redis Sentinel’s sensitivity:

* **Increased `down-after-milliseconds`** from a default aggressive setting (e.g., 5000 ms) to a safer value like **20,000 ms**. This small tweak gave Redis pods enough grace period to handle transient network issues without jumping to conclusions.

#### Step 2: Pod Anti-Affinity Rules

We ensured Redis pods were scattered across multiple Kubernetes nodes. This simple change significantly reduced simultaneous pod evictions during node maintenance:

```yaml
podAntiAffinityPreset: hard
```

#### Step 3: Pod Disruption Budgets (PDB)

PDBs were the real game changer. By setting:

```yaml
pdb:
  create: true
  minAvailable: 2
```

we guaranteed at least two Redis pods remained alive during node updates, drastically lowering the risk of split-brain occurrences.

#### Step 4: Graceful Kubernetes Drains

We added a patient touch to node upgrades:

```shell
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --grace-period=60 --timeout=5m
```

Giving pods extra time to gracefully shut down reduced the chance of unexpected Sentinel master elections.

#### Step 5: Intelligent Automation (Not Blind Failover)

Initially, we thought automating a failover command (`redis-cli sentinel failover mymaster`) at every Redis pod startup would help. But blind automation created instability. Instead, we implemented a smarter script that checked the Sentinel’s master state and triggered failover only when truly necessary.

### The Calm After the Storm

After deploying these careful yet straightforward changes, the midnight alerts dramatically decreased. The cluster stabilized, and Redis Sentinel now truly acts as a vigilant guardian rather than a trigger-happy trouble-maker.

### Key Takeaways:

* **Backups help recovery but don't prevent split-brain**.
* **Tuning Sentinel parameters** prevents overly sensitive failovers.
* **Using Pod Disruption Budgets** safeguards your Redis pods during routine Kubernetes maintenance.
* **Intelligent scripting** beats blind automation every time.

By understanding and addressing Redis Sentinel’s quirks, we transformed our cluster from a midnight nightmare into a calm and predictable dream.
