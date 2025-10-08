---
layout: post
title:  "Navigating Network Bindings: Understanding `localhost`, `127.0.0.1`, `0.0.0.0`, and `*`"
date:   2025-09-14 14:41:26 +0100
categories: MySQL
---

# Navigating Network Bindings: Understanding `localhost`, `127.0.0.1`, `0.0.0.0`, and `*`

When you run multiple services on your local machine that need to listen on network ports, understanding network binding addresses is crucial for avoiding conflicts and ensuring your applications connect to the correct service.

## Step 1: Demystifying Localhost vs. 127.0.0.1

| Term | Type | IP Address | MySQL Client Behavior |
| :--- | :--- | :--- | :--- |
| **`localhost`** | **Hostname** | Usually `127.0.0.1` | **Often tries a Unix socket connection** (not TCP/IP), which can fail for Docker or SSH tunnels. |
| **`127.0.0.1`** | **IPv4 Loopback** | `127.0.0.1` | **Always forces a TCP/IP connection** (recommended for local testing). |

## Step 2: Understanding `0.0.0.0` and `*` Bindings

These addresses specify *which network interfaces* a service should listen on.

| Term | Meaning | Interfaces Covered |
| :--- | :--- | :--- |
| **`0.0.0.0`** | **IPv4 Wildcard** | Listens on **all available IPv4 interfaces**, including `127.0.0.1` and your external network IP. |
| **`*`** | **Shorthand Wildcard** | Acts the same as `0.0.0.0` or `::` (IPv6 wildcard) in most contexts—listens on **all interfaces**. |

## Step 3: The Port Conflict Scenario & Identifying the Full Command

A port conflict is often avoided because two services listen on different interfaces, such as one on the universal `0.0.0.0:3306` and one on the specific `127.0.0.1:3306`.

To confirm exactly which process is which, you must inspect the full command.

### Identifying the Full Process Command

The `lsof` tool shows the PID, but the `ps` tool shows the full command associated with that PID.

1.  **Run `lsof`** to find the PIDs listening on the port (e.g., 3306):

    ```bash
    sudo lsof -i :3306 -t
    ```

2.  **Run `ps`** to see the full command for those PIDs:

    ```bash
    ps -fp $(sudo lsof -i :3306 -t)
    ```

| Command Snippet in `ps` Output | Service Confirmed |
| :--- | :--- |
| `docker-proxy -host-ip 0.0.0.0 -container-port 3306 ...` | **Docker Container** |
| `ssh -L 3307:localhost:3306 user@...` | **SSH Tunnel** |
| `/usr/sbin/mysqld --daemonize --pid-file=...` | **Local/Host MySQL Server** |

-----

## Step 4: Connecting to the Correct MySQL Instance

Use the **`-h`** (host) and **`-P`** (port) flags on the `mysql` client to connect explicitly to the correct service.

  * **To Docker (using the global binding):** Connect using your machine's actual network IP address (e.g., `192.168.1.10`) to ensure you hit the Docker proxy.

    ```bash
    mysql -h 192.168.1.10 -P 3306 -u docker_user -p
    ```

  * **To SSH Tunnel (using the loopback binding):** Connect using the loopback IP address.

    ```bash
    mysql -h 127.0.0.1 -P 3306 -u remote_user -p
    ```

## Step 5: The Golden Rule - Avoid Port Conflicts Entirely 🛡️

To maintain a stable development environment, always configure a unique host port for each service.

| Service | Host Port | SSH Command / Docker Config | MySQL Connection Command |
| :--- | :--- | :--- | :--- |
| **Docker DB** | `3306` | `-p 3306:3306` | `mysql -h 127.0.0.1 -P 3306 -u user -p` |
| **SSH Tunnel** | `3307` | `ssh -L 3307:remote_db:3306 user@host` | `mysql -h 127.0.0.1 -P 3307 -u user -p` |
