---
layout: post
title: "Tightening a dev VM that was quietly living without a firewall"
date: 2026-08-10 07:15:00 +0000
author: "Joey Wang"
description: "What a routine security audit found on a small always-on dev VM — unauthenticated databases, no host firewall, over-privileged automation — and the fixes that made it boring again."
tags: [devops, security, self-hosting, linux, containers, iptables, automation]
categories: [Engineering, DevOps]
---

# Tightening a dev VM that was quietly living without a firewall

I spent an afternoon auditing a small always-on VM that runs my personal AI agent, a couple of VPNs, and some dev infrastructure. It started as a routine setup review. It ended with me closing a database that required no password, on a machine with a public IPv4 address.

The fix list was useful. The process of finding the list was more useful. Here is both.

## The audit that stopped being hypothetical

The box had felt fine for months. SSH was key-only. Nothing had ever been breached. The agent answered messages, the VPNs worked, scheduled jobs ran. Nothing felt broken, so nothing got looked at.

Then I actually looked.

Three quick probes changed the mood:

```bash
# what is listening, and on which interfaces?
ss -tlnp

# can I connect to the dev postgres without a password?
psql -h <host> -p <nonstandard_port> -U postgres -c "select 1"

# does redis ask for a password?
redis-cli -p <nonstandard_port> config get requirepass
```

The answers were: a lot, yes, and no.

Two containers — a dev Postgres and a dev Redis — were published on all interfaces with `trust` auth and an empty password. The Postgres prompt sat there and printed a row when I asked nicely. The Redis had no `requirepass` at all. Both were reachable from any network path the host was on, and the host has a public IP.

Redis with no auth is not a sleepy little cache. It is a write target: SSH key planting, cron overwrites, ransomware. The fact that it held zero keys was luck, not design.

## Why it happened

The usual reasons, in the usual order:

- `docker compose` publishes ports to `0.0.0.0` unless you say otherwise.
- The Postgres container was configured with `POSTGRES_HOST_AUTH_METHOD: trust` because it was "just dev".
- There was no host firewall. The cloud security group was the only barrier, and I could not see its rules from inside the box.
- Nothing audited any of this because nothing had failed.

None of those are exotic mistakes. That is the point. A dev database with no password is one of the most common setups in the industry, and on a machine with a public address it is a live finding, not a vibe.

## The checklist

I ran these before touching anything:

```bash
ss -tlnp                 # listeners and bind addresses
ufw status               # is there a host firewall?
systemctl --failed       # units that died and stayed dead
systemctl list-units     # what is actually running
docker ps                # container ports
ls -la <agent_config>/scripts # script permissions (group-writable is a smell)
```

Plus an agent-side security check: which automation jobs run with full tool access, and which command classes are auto-approved without prompting.

The port scan, the failed units, the auth probes, and the permission check each produced at least one finding. Nothing was a single smoking gun; everything was small and accumulated.

## Fix 1: stop publishing to the world

The smallest change with the largest effect: bind the published ports to loopback.

```yaml
services:
  db:
    ports:
      - "127.0.0.1:<db_port>:5432"   # was "<db_port>:5432"
  redis:
    ports:
      - "127.0.0.1:<redis_port>:6379"   # was "<redis_port>:6379"
```

Local tooling still works. Nothing outside the host can connect. Verify with `ss` and confirm there is no `0.0.0.0` line left.

## Fix 2: auth that is actually enforced

Rebinding fixes reachability. It does not fix the fact that the database had no password, so I set one and switched the auth method to SCRAM.

The gotcha: the official Postgres image only applies `POSTGRES_HOST_AUTH_METHOD` and `POSTGRES_PASSWORD` when it initializes a *new* data directory. My volume already existed, so the container recreated happily with `trust` still in `pg_hba.conf`. Config said one thing; enforcement said another.

For an existing volume you have to do it by hand:

```bash
# set the password
docker exec <db-container> psql -U postgres -c \
  "ALTER USER postgres PASSWORD '<generated>';"

# rewrite pg_hba.conf: only the host lines, local socket admin stays
docker exec <db-container> sed -i \
  's/^\(host.*\)trust$/\1scram-sha-256/' \
  /var/lib/postgresql/data/pg_hba.conf

# reload
docker exec <db-container> psql -U postgres -c "SELECT pg_reload_conf();"
```

Then prove it both ways:

```bash
PGPASSWORD='' psql -h 127.0.0.1 -p <db_port> -U postgres -c "select 1"   # must fail
PGPASSWORD='<generated>' psql -h 127.0.0.1 -p <db_port> -U postgres -c "select 1"  # works
```

Redis is the same story in one line:

```bash
command: ["redis-server", "--requirepass", "${REDIS_PASSWORD}"]
```

## Fix 3: a host firewall, careful about the VPN

The cloud security group is not a firewall I can see. I wanted defense in depth that I *can* see, so I added targeted drops on the host: inbound SMTP, rpcbind, and NFS ports that no service actually needs.

Two rules for myself:

1. **Never touch the FORWARD chain.** VPN client traffic flows through it; messing with it risks breaking connectivity for everyone who routes through this box. INPUT drops only affect connections to the host itself.
2. **Keep SSH and the VPN ports open, always.**

I applied the drops with an idempotent script (delete existing instances, then apply) behind a small systemd oneshot unit so it survives reboots:

```bash
# /usr/local/sbin/fw-hardening.sh — the delete-then-apply pattern
iptables -D INPUT -p tcp --dport 25 -j DROP 2>/dev/null
iptables -A INPUT -p tcp --dport 25 -j DROP
```

I learned why idempotency matters the hard way: the first version checked-then-inserted, and when the unit ran a second time at `enable --now`, I ended up with duplicate rules. The delete-then-apply form makes re-running safe, and rollback is just the delete lines.

## Fix 4: small hygiene

- SSH: explicit `PermitRootLogin no` drop-in instead of relying on the default.
- Two dead services that failed at boot and stayed enabled: disabled and masked.
- Group-writable scripts in the automation directory: `chmod 755`.

None of these are exciting. They are the difference between a host that was accidentally secure and one that is deliberately boring.

## Fix 5: least privilege for the automation

The agent-side audit found the same disease I had just cured in the containers: things running with more power than they need.

- Six scheduled jobs ran with full tool access. Each job now gets a minimal toolset: a briefing job gets file access and the shell; a research job additionally gets web access; nothing gets tools it does not use.
- The auto-approval list included broad command classes: recursive delete, inline shell execution. Those now require explicit approval every time.

I kept one sandboxed script-execution tool auto-approved, deliberately, because it is core to how the agent works day to day. That is a tradeoff, and it should be a decision, not a default. Everything else went behind an approval prompt.

## The memory lesson, on the side

The same review caught a cost problem that is adjacent to security: a local language model server was running all the time, holding about 6.6 GB of RSS on a 12 GB host, as the last-resort fallback for the agent. It is used for bounded tasks a few times a week.

It is now on-demand: stopped and disabled by default, started for a task, stopped when the task ends. Service states are now explicit:

```text
must-run    -> SSH, VPN, the agent control plane, the firewall unit
on-demand   -> local model server, databases, container workloads
retired     -> whatever is backed up and documented, then removed
```

The on-demand model server also makes the fallback chain honest: it is the last entry, reached only if the primary and every cloud fallback fail, and if it is not running it fails fast instead of pretending to be a safety net.

## Lessons

- **A dev server is a production server to anyone on the internet.** "It is just dev" is a story you tell yourself; the port scanner does not care.
- **Localhost binding is not automatic.** Compose publishes to all interfaces unless you say `127.0.0.1:`.
- **Verify enforcement, not config.** The Postgres container "had" a password env var; the database still accepted empty credentials. The test is `passwordless login must fail`, not "the YAML looks right".
- **A cloud security group is not a firewall you can see.** Add one you can see, and write down the rollback.
- **Least privilege applies to automation too.** Scheduled jobs and agent tools need the same scrutiny as container ports.
- **Documentation near the system beats memory.** Every change in that session got a note next to the thing it changed, including the one-liner to undo it.

None of this was clever. It was a checklist, applied honestly, with tests that prove the fix actually worked. That is the entire trick.
