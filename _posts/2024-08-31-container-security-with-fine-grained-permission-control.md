---
layout: post
title: "Container Security with Fine-Grained Permission Control"
description: "How Linux file permissions and Kubernetes securityContext settings enforce least-privilege access for containerized workloads, with a worked example."
date: 2024-08-31 00:00 +0000
categories: [Security]
tags: [container, security, kubernetes, linux]
---

<audio controls preload="metadata" src="/assets/audio/container-security-with-fine-grained-permission-control-summary.ogg">
  Your browser does not support the audio element.
</audio>

A container gives an application a lightweight, consistent environment, but it doesn't give you permission control for free. Controlling which users and processes can touch which resources is still your job. Here's how to implement fine-grained permission control in containers, using Kubernetes as the example.

## Understanding Permission Symbols

Linux file permissions are the foundation of access control for files and directories. Permissions are typically represented in both symbolic and octal formats. Here's a breakdown of the symbolic representation:

```
-rw-r-x---
```

This translates to the following octal values:

- User permissions: `rw-` or `6` (4 for read, 2 for write)
- Group permissions: `r-x` or `5` (4 for read, 1 for execute)
- Others permissions: `---` or `0` (no permissions)

### Calculating Octal Values

The octal value is calculated by adding the individual permission values together for each category (user, group, others):

```
-rw-rw----
110 110 0 = 432
```

## Container Security: Separating Executors and Accessors

To enhance security, it's important to separate the roles of executors and accessors within a containerized environment. This can be achieved by:

1. **Running processes as non-owners of the program files**: This prevents the process from having more privileges than necessary, reducing the risk of unauthorized access or modification.
2. **Limiting process access to essential resources**: Restricting the resources a process can use minimizes the potential impact of a security breach.
3. **Controlling access to sensitive operations**: This includes network access, temporary file writing, log file writing, and more.

## Implementing Security Contexts in Kubernetes

Kubernetes provides a `securityContext` field that allows you to specify the user and group IDs for running containers, ensuring that they have the appropriate permissions.

### Example Kubernetes YAML Configuration

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  containers:
  - name: web
    volumeMounts:
    - mountPath: /mnt/credentials
      name: storage-credentials
      readOnly: true
    securityContext:
      runAsUser: 1000
      runAsGroup: 1000
      runAsNonRoot: true
      fsGroup: 2000
      supplementalGroups:
      - 4000
  volumes:
  - name: storage-credentials
    secret:
      defaultMode: 432
      secretName: storage-credentials
```

### Explanation

- `runAsUser` and `runAsGroup`: These fields specify the user and group IDs under which the container process should run.
- `runAsNonRoot`: This ensures that the container runs as a non-root user, enhancing security.
- `fsGroup`: This sets the group ID for the filesystem, which is particularly useful for volume mounts.
- `supplementalGroups`: This allows you to specify additional group IDs that the container process should be a part of.

### Verifying Permissions

After applying the above configuration, you can verify the permissions and group memberships using the following commands:

```bash
$ ls -l /mnt/credentials/..data/keyfile.json
-rw-rw---- 1 root 2000 2380 Sep  2 18:07 /mnt/credentials/..data/keyfile.json

$ ps -o uid,gid,rgid,supgid -p 1
  UID   GID  RGID SUPGID
 1000  1000  1000 100,1000,2000

$ id
uid=1000(app) gid=1000(app) groups=1000(app),100(users),2000

$ groups app
app : app users

$ getent group app
app:x:1000:
```

## The principle

Running a container process as its own file owner, with write access to nothing it doesn't need, is what turns "someone got code execution" into "someone got a mostly useless shell." `securityContext` and Unix file permissions are the two levers, and both are worth setting explicitly rather than trusting defaults.

Reference
---
* https://kubernetes.io/docs/tasks/configure-pod-container/security-context/#set-the-security-context-for-a-pod
* https://www.redhat.com/sysadmin/suid-sgid-sticky-bit
* https://www.binaryhexconverter.com/binary-to-decimal-converter
