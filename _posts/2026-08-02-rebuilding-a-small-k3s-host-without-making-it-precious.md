---
layout: post
title: "Rebuilding a Small k3s Host Without Making It Precious"
date: 2026-08-02 10:30:00 +0100
author: "Joey Wang"
description: "Notes from wiping an old single-node k3s setup and rebuilding it with a smaller, cleaner baseline for ingress, certificates, and storage."
tags: [kubernetes, k3s, traefik, longhorn, devops, homelab]
categories: [Engineering, DevOps]
---

# Rebuilding a small k3s host without making it precious

I had an old single-node k3s machine that had done what small Kubernetes machines often do: accumulate history.

A namespace for something I once tested. A storage system with old volumes. A CronJob whose target no longer existed. Some broken pods that were not hurting anything directly, but were making every health check noisy. The cluster still ran, but it no longer explained itself quickly.

That is usually the point where I stop trying to perform archaeology.

For a production cluster, I would plan a careful migration. For this machine, the better answer was to make it disposable again: remove the unused workloads, wipe k3s, install the current stable release, and rebuild only the baseline services I actually want.

This post is the sanitized version of that rebuild. I am leaving out hostnames, IP addresses, private repository names, and anything that would make the machine identifiable. The useful part is the shape of the work, not the address of the box.

## The starting smell

The cluster had several signs that it was time to clean up rather than patch around the edges:

- old namespaces with no live workload behind them
- a broken scheduled job repeatedly failing because its service account was gone
- storage objects from previous experiments
- warning events that made real problems harder to see
- a Kubernetes version that was far behind current stable

None of these are dramatic by themselves. Together they create a cluster that feels older than it is.

The most important question was not "can I fix each warning?" It was:

> Is any service on this cluster still important?

Once the answer was no, the rebuild became much simpler.

## First rule: delete with intent

Before wiping k3s, I still wanted to know what I was deleting. Not because the data mattered, but because accidental deletion is a bad habit to train.

The rough inventory was:

```bash
kubectl get ns
kubectl get deploy,sts,ds,cronjob,job,pod,pvc -A -o wide
kubectl get events -A --sort-by=.lastTimestamp --field-selector type=Warning
```

That gave a quick view of what was still alive, what was only historical noise, and which warnings were real.

For unused namespaces, I deleted them deliberately rather than trying to preserve a half-working state:

```bash
kubectl delete namespace <unused-namespace>
```

For the broken CronJob, the key was to remove both the schedule and the thousands of failed Jobs it had already created. Otherwise the cluster looked unhealthy even after the cause was gone.

## Wipe beats upgrade for disposable clusters

A normal k3s upgrade is straightforward:

```bash
curl -sfL https://get.k3s.io | sh -
```

But if the workloads are not needed, upgrading an untidy cluster can preserve the wrong thing: old assumptions.

For this host I used the uninstall script, removed leftover k3s state, and installed again from the stable channel. Conceptually:

```bash
/usr/local/bin/k3s-uninstall.sh
rm -rf /etc/rancher/k3s /var/lib/rancher/k3s /var/lib/kubelet /etc/cni/net.d
curl -sfL https://get.k3s.io | sh -
```

On a real production or shared cluster, do not copy that sequence blindly. Take backups, understand your storage backend, and plan rollback. This machine was intentionally treated as disposable.

## A smaller baseline

I prefer a fresh small k3s host to start lean.

The baseline I wanted was:

```text
k3s
  -> CoreDNS
  -> metrics-server
  -> local-path-provisioner
  -> Traefik, installed by Helm
  -> cert-manager, installed by Helm
  -> Longhorn, installed by Helm
  -> one namespace for user workloads with quotas
```

I disabled the bundled ingress/load-balancer pieces during k3s install and added the addons explicitly afterwards. That makes ownership clearer: k3s provides Kubernetes; Helm manages the platform services.

The k3s config also had a few guardrails:

- secrets encryption enabled
- a predictable node name
- kubelet resource reservations
- image garbage collection thresholds
- pod count limits for a small node

The point is not to make a single-node cluster highly available. It cannot be. The point is to make it boring, inspectable, and hard to accidentally fill with unbounded experiments.

## Addons

I installed three things immediately.

### Traefik

Traefik is the ingress controller. I installed it with Helm, created a default `IngressClass`, and exposed HTTP/HTTPS through the node.

The first verification was intentionally simple:

```bash
curl -I http://127.0.0.1/
curl -k -I https://127.0.0.1/
```

A redirect from HTTP to HTTPS and a 404 from HTTPS are both fine for an empty cluster. It means the router is listening; it simply has no application route yet.

### cert-manager

cert-manager went in next, including its CRDs.

I did not create a Let's Encrypt issuer during the rebuild because that requires real domain and email decisions. Installing cert-manager is platform setup. Issuing public certificates is an application/domain decision.

That separation is useful. A cluster can be certificate-ready without pretending every future app will use the same issuer.

### Longhorn

Longhorn is where the small-host reality showed up.

The default storage safety margins were too conservative for a host whose root disk was already fairly full. Longhorn correctly refused to schedule replicas because it wanted more free space than the machine currently had.

That failure was useful. It forced the storage policy to match the machine instead of just accepting defaults.

For this single-node setup, the important choices were:

- one replica, because there is only one node
- local data path under Longhorn's standard directory
- no default takeover of the existing local-path storage class
- lower reserved/minimum-free percentages that still leave headroom
- host prerequisites installed and verified: iSCSI, NFS client support, device-mapper/cryptsetup pieces
- multipath disabled, because it can interfere with Longhorn volumes on simple hosts

After that, I tested Longhorn with a tiny PVC and a temporary pod:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: longhorn-smoke-pvc
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: longhorn
  resources:
    requests:
      storage: 256Mi
```

The pod wrote a file, read it back, and exited successfully:

```text
longhorn-ok
```

That is a better proof than "all pods are Running". A storage system is only really installed when a workload can create a volume, mount it, write to it, and clean it up.

## The small mistakes were the useful part

Two things needed adjustment during the rebuild.

First, my initial kubelet image garbage collection threshold was too aggressive for the current disk usage. Kubernetes started warning that it wanted to reclaim image space. The fix was not complicated: set thresholds that still protect the host, but do not produce permanent warning noise on a machine that is already mostly full.

Second, Longhorn's first smoke test produced a faulted volume because the disk was marked unschedulable. The fix was to look at Longhorn's node and disk conditions instead of guessing:

```bash
kubectl get nodes.longhorn.io -n longhorn-system -o yaml
kubectl get settings.longhorn.io -n longhorn-system
kubectl get volumes.longhorn.io -n longhorn-system
```

The condition message pointed directly at available space. Once the storage settings matched the host, the same smoke test passed.

This is the part I want to remember: install success is not the same as operational success. The proof is in the smallest real workload you can run through the system.

## The final shape

At the end, the cluster was intentionally small:

```text
kube-system
  CoreDNS
  metrics-server
  local-path-provisioner

traefik
  ingress controller

cert-manager
  certificate CRDs and controllers

longhorn-system
  Longhorn manager, UI, CSI components, engine image

apps
  default place for future workloads, with quota and limits
```

The `apps` namespace has a `LimitRange` and `ResourceQuota`, so random tests cannot silently consume the whole machine.

That is probably the most important "best practice" on a small box: do not confuse a lab cluster with infinite infrastructure.

## What I would add only when needed

I did not immediately add everything that a larger platform might have:

- no public Longhorn UI ingress yet
- no Let's Encrypt issuer yet
- no monitoring stack yet
- no external DNS automation yet
- no GitOps controller yet

Those are useful, but they each create another maintenance surface. For a small personal host, the best default is often not "install the platform checklist". It is "install the minimum that makes the next workload safe".

The cluster is now boring again. That is the outcome I wanted.

Not impressive. Not clever. Just clean enough that the next problem should be visible when it arrives.
