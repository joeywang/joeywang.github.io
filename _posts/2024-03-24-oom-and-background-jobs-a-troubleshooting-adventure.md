---
layout: post
title: 'OOM and Background Jobs: A Troubleshooting Adventure'
date: 2024-03-24 00:00 +0000
categories: OOM
tags: [oom, troubleshooting]
---
# OOM and Background Jobs: A Troubleshooting Adventure

## The Mystery Unfolds

A few months ago, we received an urgent complaint from a customer: a notification email had failed to reach him on time. As the assigned detective of the digital realm, I embarked on a mission to unravel the mystery.

1. **Sentry Logs**: A blank canvas, no traces of foul play.
2. **Sidekiq Logs**: A void, offering no helpful breadcrumbs.
3. **Job Queue**: An empty river, with no logs to float downstream.

However, a deja vu struck me, reminiscent of another case where a Sidekiq job was abruptly ended by the OOM killer, leaving a Redis lock in limbo. I decided to probe the OOM enigma and, after relentless pursuit, uncovered the culprit. It was indeed the OOM Killer.

### Unmasking the OOM Killer

OOM, or Out Of Memory, is the digital equivalent of a bank robbery where the perpetrator, a system, application, or container, steals more memory than available. This heist leads to a hostage situation, where performance is held ransom or processes are terminated to free up resources. In the Kubernetes arena, OOM can be a fatal blow when a container exceeds its memory limit, prompting the OOM killer to swoop in, terminate the process, and reclaim memory.

### The Kernel's Deadly Arsenal

Deep in the heart of the Linux operating system, the kernel wields the OOM killer—a sharp, double-edged sword—to slay processes that guzzle excessive memory when the system's reserves are critically low. This killer assigns an 'oom_score' to each process, a telltale number indicating the likelihood of a process meeting its demise during an OOM event.

### The Kubernetes OOM Saga

In the orchestrated chaos of Kubernetes, the kubelet is the diligent custodian of containers, ensuring they respect the memory limits set before them. Should a container dare to surpass its memory limit, the kubelet does not take the law into its own hands. Instead, it beckons the Linux kernel's OOM killer, a silent avenger within the host's operating system, to mete out justice.

### Unearthing Clues with Command Line Tools

To piece together the puzzle of OOM events, I turned to a arsenal of command-line tools and system files:

1. **`dmesg`**: This command unveils messages from the kernel's ring buffer, which may harbor logs of the OOM killer's recent activities.
2. **`/var/log/kern.log`**: On some systems, this is the final resting place for kernel logs, which can be exhumed for OOM events.
3. **`/proc/<pid>/oom_score`**: Reveals the OOM score of a specific process, a score that could mean the difference between life and death.
4. **`/proc/<pid>/oom_score_adj`**: Allows the adjustment of a process's OOM score, where a lower value is akin to donning kevlar in this deadly game.

### The Grim Algorithm of the OOM Reaper

The OOM killer employs a cold calculus to calculate a score for each process based on several merciless factors:

- **Resident Set Size (RSS)**: The amount of non-swapped physical memory a process is using, akin to a gluttonous feast.
- **Proportional Set Size (PSS)**: The share of the memory consumed by a process when in the company of other processes.
- **Kernel Same Priority Threads (KSPT)**: The count of same-priority kernel threads, a sibling rivalry that can turn deadly.
- **User Space Execution**: Processes running in user space are more likely to face the executioner than those dwelling in kernel space.
- **OOM Score Adjustment**: A tunable parameter, a slight of hand that can make a process either more of a target or less likely to be slain by the OOM killer.

### Strategies to Evade the OOM Guillotine

To sidestep the grim reaper of OOM issues, consider these cunning strategies:

1. **Monitor Memory Usage**: Keep a hawk-eyed vigil on the memory consumption of applications and containers.
2. **Set Appropriate Memory Limits**: Ensure that the memory limits set for containers match their true appetite.
3. **Optimize Application Code**: Snip memory leaks and prune memory usage in the application code.
4. **Employ Efficient Data Structures**: Choose data structures that sip memory, not guzzle it.
5. **Implement Caching Strategies**: Use caching with the discretion of a connoisseur, to avoid overindulgence in memory use.
6. **Scale Horizontally**: Multiply the number of nodes or pods to disperse memory usage, like drops of water in a vast ocean.
7. **Use Quality of Service Classes**: In Kubernetes, employ QoS classes to anoint critical workloads, making them less likely to be sacrificed during OOM events.
