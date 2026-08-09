---
layout: post
title: "When an Always Free server gets smaller"
date: 2026-08-08 10:45:00 +0000
author: "Joey Wang"
description: "What Oracle's smaller Ampere A1 Always Free limits mean for a self-hosted ARM server, and how I reshaped mine around a 12 GB memory budget."
tags: [devops, cloud, oracle, arm, self-hosting, cost]
categories: [Engineering, DevOps]
---

Oracle's Always Free ARM instance used to feel unusually generous.

For a long time, the practical mental model was simple: one Ampere A1 VM with 4 OCPUs and 24 GB of memory, or the same total split across smaller instances. That is enough to run a surprising amount of personal infrastructure: VPNs, a small Kubernetes cluster, databases, background workers, an AI agent control plane, local experiments, and whatever else slowly accumulates on a machine that is always on.

The current public shape is smaller. Oracle's Always Free documentation now says Ampere A1 VM instances get the first **1,500 OCPU hours** and **9,000 GB-hours** per month for free. Oracle describes that as equivalent to **2 OCPUs and 12 GB of memory** for Always Free tenancies. The Oracle Cloud Free Tier page says the same thing more directly: Arm-based Ampere A1 cores and **12 GB of memory**, usable as one VM or two VMs.

That changes the engineering question.

It is no longer: "What can I fit on a very generous free ARM box?"

It is: "What deserves to be always-on if the honest budget is 2 cores and 12 GB?"

## The reference points

The useful public references are:

- Oracle's Always Free Resources documentation: <https://docs.oracle.com/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm>
- Oracle Cloud Free Tier page: <https://www.oracle.com/cloud/free/>
- Oracle Ampere A1 compute page: <https://www.oracle.com/cloud/compute/arm/>
- Oracle Cloud price list: <https://www.oracle.com/cloud/price-list/>
- Oracle Cloud Free Tier FAQ: <https://www.oracle.com/cloud/free/faq/>

The important lines, as of this writing:

- Always Free Ampere A1 VM usage: **1,500 OCPU hours** and **9,000 GB-hours** per month.
- For Always Free tenancies, Oracle says that is equivalent to **2 OCPUs and 12 GB of memory**.
- Oracle's Free Tier page lists Arm compute as **12 GB of memory usable as 1 VM or 2 VMs**.
- Oracle's Ampere page lists A1 pricing at **$0.01 per OCPU-hour** and **$0.0015 per GB-hour**.
- The FAQ says Always Free services are available for an unlimited period, but also says Free Tier availability is subject to capacity limits and that listed capacity estimates can change.

That last pair is the tension.

## The contract-shaped expectation

I do not think most people read "Always Free" as a benchmark number. They read it as a promise.

Not necessarily a promise that every quota will be frozen forever. Cloud providers change instance families, limits, abuse controls, capacity policies, and commercial packaging all the time. But "Always Free" creates a stronger expectation than "trial" or "promotional credit". If a provider trains users to build around a free shape, and that shape later becomes smaller, the change feels less like ordinary pricing maintenance and more like a contract-shaped disappointment.

There is a legal version of that discussion, and I am not trying to make it here. The practical engineering version is enough:

```text
Marketing promise: this is Always Free
Operational reality: capacity and limits can change
User response: design the system as if the shape is not guaranteed
```

That sounds cynical, but it is just the cloud version of not treating someone else's free tier as your only production plan.

The fair reading is probably this: the account can still have Always Free resources for an unlimited period, but the resource envelope is not an immutable interface. If you need a particular shape, you should budget for it or have a downgrade plan.

## The cost of pretending nothing changed

The old practical shape was 4 OCPUs and 24 GB of RAM running continuously.

At Oracle's published Ampere A1 rates:

```text
OCPU:   $0.01 per OCPU-hour
Memory: $0.0015 per GB-hour
```

A full 4 OCPU / 24 GB machine for an average 730-hour month is roughly:

```text
4 OCPUs * 730 hours * $0.01      = $29.20
24 GB   * 730 hours * $0.0015    = $26.28
Gross monthly shape cost         = $55.48
```

If the first 1,500 OCPU-hours and 9,000 GB-hours are free, then keeping the old 4 / 24 shape continuously means paying for the part above the new free envelope:

```text
Billable OCPU-hours: (4 * 730) - 1,500 = 1,420
Billable GB-hours:   (24 * 730) - 9,000 = 8,520

OCPU overage:   1,420 * $0.01    = $14.20
Memory overage: 8,520 * $0.0015  = $12.78
Estimated monthly overage        = $26.98
```

For a 31-day month the estimate is about **$28.04**. For a 30-day month it is about **$26.22**.

That is not an outrageous bill. In fact, for a 4-core ARM VM with 24 GB of RAM, it is still cheap.

But it changes the category. A free hobby host becomes a small paid server. That may be perfectly fine, but it should be an explicit decision, not something discovered after the bill arrives.

## My target shape: 12 GB, not nostalgia

I decided to treat 12 GB as the real design constraint.

The point was not to recreate the old host badly. The point was to decide what the host is actually for.

For me, the always-on role is:

```text
small ARM host
  -> private access paths
  -> basic shell and development access
  -> lightweight automation
  -> scheduled maintenance
```

Everything else has to justify itself.

That means the host should keep only the boring access and automation layer always running. Heavier platform services, databases, container workloads, local model servers, and one-off experiment processes should become explicitly on-demand.

That is the important shift: not "can I squeeze it all in?" but "should this be always-on?"

## Shutting things down without deleting them

The safe version of downsizing is not to uninstall everything in a panic.

For each service, I want one of three states:

```text
must-run      -> enabled and monitored
on-demand     -> stopped and disabled, data retained
retired       -> backed up, documented, then removed later
```

For this host, the first pass was mostly "on-demand": stop services, disable boot-time autostart, keep the data.

A service table is more useful than a vague note:

| Component | New default | Start when needed | Stop after use |
| --- | --- | --- | --- |
| k3s | stopped + disabled | `sudo systemctl start k3s` | `sudo systemctl stop k3s && sudo k3s-killall.sh` |
| MySQL | stopped + disabled | `sudo systemctl start mysql` | `sudo systemctl stop mysql` |
| Multipass | stopped + disabled | `sudo systemctl start snap.multipass.multipassd.service` | `sudo systemctl stop snap.multipass.multipassd.service` |
| WARP | stopped + disabled | `sudo systemctl start warp-svc.service` | `sudo systemctl stop warp-svc.service` |
| Local LLM server | on-demand | start the model server for a bounded task | stop it when the task ends |

The Kubernetes line matters. Stopping `k3s` is not always enough, because container shims, mounts, CNI state, and iptables rules can linger. `k3s-killall.sh` is useful because it clears runtime state without uninstalling k3s or deleting persistent data.

That gives me a reversible downgrade. If I need the cluster for an experiment, I can start it. If I do not, it is not allowed to quietly consume RAM every day.

## Verification before resizing

Before changing the cloud shape, I want evidence that the smaller role is already true on the larger host.

The checklist is boring on purpose:

```bash
hostname
uname -m
nproc
free -h
swapon --show

df -h /
systemctl is-active <must-run-services> || true
systemctl is-enabled <must-run-services> || true
systemctl is-active <on-demand-services> || true
systemctl is-enabled <on-demand-services> || true
ss -tulpn
```

The expected result is:

- remote access is reachable.
- the required private access paths are present.
- the automation layer still answers a smoke test.
- heavier optional services are inactive and disabled.
- unnecessary listeners are gone.
- available memory looks healthy before the resize.

The resize itself is still a stop/start event. If the host runs the automation path that talks to me, I should expect that path to be offline during the shape change unless I intentionally fail it over first.

## Backups are part of the shape change

A smaller server is not just a smaller server. It is also a forcing function for deciding what is precious.

Before resizing, I want backups for the things that would be annoying or risky to reconstruct:

- VPN configuration
- SSH configuration
- firewall and network configuration
- systemd units/drop-ins for must-run services
- Hermes configuration, scripts, cron jobs, plugins, and skills
- enough package/system state to understand how the host was assembled

The backup should be encrypted or permission-restricted, checksummed, and copied somewhere other than the host being resized. It should also be treated as sensitive. A restore archive for VPN, SSH, and agent configuration is not a blog artifact; it is effectively infrastructure authority in a tarball.

The goal is not to make the host precious. It is the opposite: make the host disposable enough that a failed resize is inconvenient, not existential.

## The lesson

The Oracle change is annoying because the old free ARM shape was genuinely useful. A 4 OCPU / 24 GB always-on machine is enough to hide architectural laziness for a long time.

The smaller 2 OCPU / 12 GB shape is less forgiving, but it is still useful if the host has a clear job.

My rule now is:

```text
free tier = great control plane
free tier != dumping ground
```

If I need the old shape continuously, the honest cost is roughly $27 to $28 per month above the new Always Free envelope. That is cheap enough to consider and expensive enough to make me clean up first.

So the plan is to downsize the host, not the responsibility:

- keep VPN, SSH, and Hermes always-on
- move databases, Kubernetes, local models, and helper daemons to on-demand
- verify the lean state before resizing
- keep sensitive restore backups elsewhere
- treat "Always Free" as a useful offer, not a capacity contract I build my life around

That is a healthier design anyway. The cloud provider changed the limits; the useful response is to make the machine's purpose smaller and clearer.
