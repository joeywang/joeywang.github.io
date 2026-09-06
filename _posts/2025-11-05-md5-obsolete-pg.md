---
title: "PostgreSQL MD5 to SCRAM-SHA-256: a zero-downtime migration"
description: "PostgreSQL 18 deprecates MD5 authentication, and migrating to SCRAM-SHA-256 in mixed mode lets you switch pg_hba.conf without downtime or forced app changes."
date: 2025-11-05
tags: [postgresql, security, kubernetes, database, devops]
categories: [Database, Security]
---

<audio controls preload="metadata" src="/assets/audio/md5-obsolete-pg-summary.ogg">
  Your browser does not support the audio element.
</audio>

PostgreSQL has supported MD5 password authentication for over a decade, but MD5 is now cryptographically broken: fast to brute-force on a GPU, easy to crack offline if the hash leaks, and it gives you no server authentication at all, so a client can be tricked by a fake Postgres instance. PostgreSQL 18 marks it deprecated, and the mixed-mode support that already exists makes now a reasonable time to move to SCRAM-SHA-256 instead of waiting for the deadline.

## What SCRAM-SHA-256 buys you

SCRAM (Salted Challenge Response Authentication Mechanism, RFC 5802) hashes passwords with SHA-256 instead of MD5, salts them to block rainbow tables, iterates the hash to make brute-forcing expensive, and adds a challenge-response exchange so client and server authenticate each other. No password-equivalent value crosses the network.

| Aspect | MD5 | SCRAM-SHA-256 |
| --- | --- | --- |
| Hash strength | Weak | SHA-256 |
| Salted | Yes | Yes |
| Iterated hashing | No | Yes |
| Replay protection | Limited | Strong |
| Server authentication | None | Yes |
| PostgreSQL 18+ | Deprecated | Fully supported |

MD5 is easy to crack; SCRAM is hard to break even with stolen verifier data.

A related question is whether to reach for TLS client certificates (mTLS) instead. SCRAM covers most application and user authentication at low operational cost. mTLS is stronger but needs a PKI to run it, which is worth the overhead for machine-to-machine auth in regulated environments, not for everyday app connections. TLS in transit plus SCRAM for authentication covers most workloads.

## Migrating with zero downtime

PostgreSQL lets users carry either MD5 or SCRAM passwords at the same time, with `pg_hba.conf` still set to `md5` and the server negotiating SCRAM automatically when the stored hash is SCRAM. That mixed mode is what makes a gradual migration possible.

1. **Switch new password hashing to SCRAM:**

   ```sql
   ALTER SYSTEM SET password_encryption = 'scram-sha-256';
   SELECT pg_reload_conf();
   ```

2. **Rotate every role's password** (app users, human users, the replication user, and any proxy's backend user), reusing the same plaintext password if you want:

   ```sql
   ALTER ROLE app_user PASSWORD 'secret';
   ```

3. **Verify nothing is still on MD5:**

   ```sql
   SELECT rolname, rolpassword ~ '^SCRAM-SHA-256' AS is_scram
   FROM pg_authid WHERE rolcanlogin;
   ```

   Don't move on until every login role comes back `true`.

4. **Flip `pg_hba.conf`** from `md5` to `scram-sha-256` and reload. No forced app changes, no new credentials, no downtime.

## Pgpool and PgBouncer

There are two authentication flows to account for: client to proxy, which is untouched unless you change the proxy's own auth settings, and proxy to PostgreSQL, which must support SCRAM. That means the proxy needs a libpq recent enough to speak SCRAM, and its backend user needs a SCRAM password before you enforce SCRAM on the PostgreSQL side. Pgpool can keep authenticating clients with MD5 independently of what its backend connection uses. PgBouncer just needs `auth_type = scram-sha-256` once its backend users are migrated, or it can keep MD5 for client connections since that's independent of PostgreSQL's own MD5 removal.

## Doing this in Kubernetes (Kubegres)

Kubegres manages the cluster through a StatefulSet with ConfigMaps for `postgresql.conf` and `pg_hba.conf`, which keeps this migration from requiring pod restarts until the very end. `ALTER SYSTEM` writes to `postgresql.auto.conf` without a restart, and password rotations don't need one either. The sequence:

1. Apply the SCRAM default hashing with `ALTER SYSTEM` as above.
2. Rotate all users' passwords, the Pgpool backend user and replication user included.
3. Edit the ConfigMap to flip `pg_hba.conf` to `scram-sha-256`.
4. Disable Kubegres failover temporarily, then roll pods with `kubectl rollout restart statefulset/mydb`.
5. Re-enable failover and confirm: Pgpool connects, apps connect, no MD5 hashes remain, and PostgreSQL's logs show SCRAM authentication.

Given MD5's coming removal and PostgreSQL's mixed-mode support, there's little reason to wait: rotate passwords, verify, flip `pg_hba.conf`, done.
