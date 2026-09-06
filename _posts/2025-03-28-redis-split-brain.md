---
title: "Redis Sentinel Split-Brain: Fixing It on Kubernetes"
description: "How Redis Sentinel split-brain happens during Kubernetes node maintenance, and the sentinel tuning, anti-affinity, and PDB changes that stopped it."
date:   2025-03-28 14:41:26 +0100
categories: [DevOps, Database]
tags: [redis, kubernetes, devops, database]
---
<audio controls preload="metadata" src="/assets/audio/redis-split-brain-summary.ogg">
  Your browser does not support the audio element.
</audio>

It's 2 AM, and the phone won't stop buzzing. The Redis cluster, supposed to be the boring, reliable part of the stack, is reporting inconsistent data. That's split-brain: Redis Sentinel.

### The tale of two masters

Split-brain happens when a network partition or node failure splits the Sentinel cluster into factions that each believe the other side has failed. Each faction elects its own master. Now two Redis nodes are both accepting writes, and the data diverges. In our case it kept showing up during routine maintenance: Kubernetes node upgrades evicting Redis pods and creating a brief but critical disruption.

Sentinel exists to prevent exactly this kind of downtime by detecting failures and electing a new master quickly. The irony is that the same automation, tuned too aggressively, is what causes it: short timeouts, simultaneous pod termination, and oversensitive network settings.

### What actually fixed it

Turning on regular RDB/AOF backups felt like progress at first. It wasn't. Backups are a recovery mechanism, not a prevention one. They tell you how to pick up the pieces after split-brain, not how to avoid it.

**Sentinel timeout.** We raised `down-after-milliseconds` from an aggressive default (around 5000ms) to 20,000ms. That gave pods room to survive a transient network blip without Sentinel declaring them dead.

**Pod anti-affinity**, so Redis pods land on different nodes and a single node drain doesn't take out more than one at a time:

```yaml
podAntiAffinityPreset: hard
```

**Pod Disruption Budgets** made the biggest difference. Guaranteeing at least two pods stay up during any voluntary disruption:

```yaml
pdb:
  create: true
  minAvailable: 2
```

**Graceful drains**, giving pods time to shut down cleanly instead of being yanked mid-election:

```shell
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --grace-period=60 --timeout=5m
```

**No blind automation.** We initially wired a `redis-cli sentinel failover mymaster` call into every pod startup. That made things worse: automated failover on every restart is its own source of instability. We replaced it with a script that checks Sentinel's actual master state first and only triggers failover when the state genuinely warrants it.

### The lesson

Backups help you recover from split-brain; they don't prevent it. Prevention is Sentinel timeouts matched to your real network behavior, pods spread across nodes, PDBs that guarantee quorum survives a drain, and automation that checks state before it acts instead of firing blindly. After these changes, the midnight alerts stopped being routine.
