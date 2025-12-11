---
title: "Upgrading PostgreSQL Authentication from MD5 to SCRAM-SHA-256:
Why It Matters and How to Do It Safely"
date: 2025-11-05
tags: [PostgreSQL, Security, Authentication, SCRAM, MD5, Migration, Pgpool, PgBouncer, Kubernetes, Kubegres]
---

# **Upgrading PostgreSQL Authentication from MD5 to SCRAM-SHA-256: Why It Matters and How to Do It Safely**

PostgreSQL has supported **MD5 password authentication** for over a decade, but MD5 is now considered cryptographically broken and unsafe. Modern database security standards — and PostgreSQL itself — are moving toward **SCRAM-SHA-256**, a robust, modern authentication mechanism that significantly improves password protection.

With PostgreSQL 18 marking MD5 authentication as deprecated, now is the right time to upgrade. The good news? PostgreSQL allows a **zero-downtime migration path**.

This article explains everything you need to know:

* How MD5 and SCRAM authentication work
* Why SCRAM is safer
* How to migrate with zero downtime
* How Pgpool/PgBouncer and Kubernetes (Kubegres) fit into the migration
* A complete runbook for production deployments

---

# 1. **What Is PostgreSQL MD5 Authentication?**

PostgreSQL’s MD5 authentication hashes passwords like this:

```
md5( md5(password + username) + salt )
```

This approach was once considered secure, but several major issues now make MD5 unsuitable for modern systems.

### 🚫 **MD5 Weaknesses**

* **Extremely fast to brute-force** using GPUs
* **Susceptible to hash collisions**
* **Easy to crack offline** if password hashes leak
* **Limited replay protection**
* **No server authentication** (client can be tricked by a fake PG instance)

### 🔚 **MD5 Is Deprecated in Postgres 18**

MD5 authentication will soon be removed, and MD5-stored password hashes will no longer be accepted.

---

# 2. **What Is SCRAM-SHA-256?**

SCRAM stands for **Salted Challenge Response Authentication Mechanism**, defined in RFC 5802. PostgreSQL uses **SCRAM-SHA-256**, which provides:

* Stronger cryptography
* Secure challenge-response protocol
* Protection against replay attacks
* Verification that the server is genuine

SCRAM stores passwords using a salted, iterated hashing process similar to PBKDF2.

### 🔐 **Why SCRAM Passwords Are Safer**

* Passwords are hashed using SHA-256 — not MD5
* A salt prevents rainbow-table attacks
* Iterations make brute-forcing extremely expensive
* Server and client mutually authenticate each other
* No password-equivalent value is sent over the network

---

# 3. **SCRAM vs MD5: A Clear Comparison**

| Aspect                        | MD5        | SCRAM-SHA-256   |
| ----------------------------- | ---------- | --------------- |
| Hash strength                 | Weak       | Strong SHA-256  |
| Salted                        | Yes        | Yes             |
| Iterated hashing              | ❌ No       | ✅ Yes           |
| Replay protection             | Limited    | Strong          |
| Server authentication         | ❌ None     | ✅ Yes           |
| Resistant to offline cracking | ❌ Weak     | ✅ Strong        |
| PostgreSQL 18+ support        | Deprecated | Fully supported |

### 🧠 **In practical terms:**

MD5 is easy to crack. SCRAM is difficult to break even with stolen verifier data.

---

# 4. **SCRAM and TLS Client Certificates: When to Use What**

SCRAM is excellent authentication for both applications and users. Some consider using **TLS client certificates (mTLS)** instead — here’s how they compare:

| Feature                | SCRAM              | TLS Client Certs            |
| ---------------------- | ------------------ | --------------------------- |
| Security level         | High               | Very high                   |
| Operational complexity | Low                | High                        |
| Requires PKI?          | No                 | Yes                         |
| Best for               | Most app/user auth | Machine-to-machine security |

🏆 **Recommendation:**
Use **TLS + SCRAM** for most workloads.
Use **mTLS** only in regulated or high-assurance environments.

---

# 5. **Zero-Downtime Migration to SCRAM**

PostgreSQL supports a mixed mode where:

* Users may have MD5 or SCRAM passwords
* `pg_hba.conf` can still use `md5`
* PostgreSQL automatically negotiates SCRAM if the stored hash is SCRAM

This allows a **safe, gradual migration**.

### ✔️ Step 1 — Enable SCRAM for new passwords

```sql
ALTER SYSTEM SET password_encryption = 'scram-sha-256';
SELECT pg_reload_conf();
```

### ✔️ Step 2 — Rotate all users’ passwords to SCRAM

You may reuse the same plaintext password:

```sql
ALTER ROLE app_user PASSWORD 'secret';
```

Or:

```psql
\password username
```

### ✔️ Step 3 — Verify password formats

```sql
SELECT rolname,
       rolpassword ~ '^SCRAM-SHA-256' AS is_scram
FROM pg_authid
WHERE rolcanlogin;
```

Wait until **all** users are SCRAM.

### ✔️ Step 4 — Switch `pg_hba.conf` to SCRAM

Before:

```
md5
```

After:

```
scram-sha-256
```

Reload PostgreSQL.

🎉 No downtime. No forced app changes. No new credentials required.

---

# 6. **Pgpool and PgBouncer: What Changes When Switching to SCRAM?**

There are **two authentication flows**:

1. **Client → Pgpool / PgBouncer**
   (Unaffected unless *you* change their auth settings)

2. **Pgpool / PgBouncer → PostgreSQL**
   (Must support SCRAM)

### ✔️ Requirements

* Proxy must be linked to a recent libpq (supports SCRAM)
* Proxy backend users must have SCRAM passwords
* PostgreSQL must not enforce SCRAM until proxies are SCRAM-ready

### Pgpool Considerations

* Pgpool’s backend user must be rotated to SCRAM early
* Pgpool can still authenticate *clients* using MD5 (separate system)

### PgBouncer Considerations

* Set `auth_type = scram-sha-256` once all backend users are migrated
* Or keep MD5 for client → PgBouncer; it's independent of PostgreSQL’s MD5 removal

---

# 7. **SCRAM Migration in Kubernetes (GKE + Kubegres)**

Kubegres manages PostgreSQL clusters through a StatefulSet and uses ConfigMaps for Postgres configuration.

### Why migration is easy in K8s:

* `ALTER SYSTEM` writes to `postgresql.auto.conf` (no pod restart)
* Password rotations do not require pod restarts
* SCRAM flips happen through controlled ConfigMap updates
* Kubegres supports disabling failover during planned restarts

### General flow:

1. Apply SCRAM default hashing using `ALTER SYSTEM`
2. Rotate all users' passwords
3. Edit ConfigMap (`postgres.conf`, `pg_hba.conf`)
4. Disable Kubegres failover temporarily
5. Roll pods safely using `kubectl rollout restart`
6. Re-enable failover

---

# 8. **Architecture Diagrams (Text-Based Descriptions)**

### **Diagram 1: MD5 vs SCRAM Authentication Flow**

```
┌──────────┐        ┌───────────┐
│  Client  │        │PostgreSQL │
└────┬─────┘        └─────┬─────┘
     │ MD5 hash sent       │
     │────────────────────>│   (Weak: reusable secret)
     │                     │
```

```
┌──────────┐        ┌───────────┐
│  Client  │        │PostgreSQL │
└────┬─────┘        └─────┬─────┘
     │ Nonces exchanged    │
     │ SCRAM proof sent    │
     │────────────────────>│   (Strong: zero reusable secret)
     │ Server proof back   │
     │<────────────────────│
```

### **Diagram 2: Authentication Layers with Pgpool**

```
Client  →  Pgpool  →  PostgreSQL Primary/Replica
            │               │
            │ SCRAM-ready   │ SCRAM enforced after migration
```

---

# 9. **Step-by-Step Runbook (GKE + Kubegres + Pgpool)**

### **Phase 1 — Preparation**

1. Confirm Pgpool version supports SCRAM
2. Identify Pgpool backend user
3. Ensure apps/drivers support SCRAM (most do)

### **Phase 2 — Enable SCRAM Hashing**

```sql
ALTER SYSTEM SET password_encryption = 'scram-sha-256';
SELECT pg_reload_conf();
```

### **Phase 3 — Rotate Passwords**

Rotate:

* App users
* Human users
* Pgpool backend user
* Replication user

Verify all are SCRAM:

```sql
SELECT rolname, rolpassword ~ '^SCRAM-SHA-256' FROM pg_authid;
```

### **Phase 4 — Flip `pg_hba.conf` to SCRAM**

Update ConfigMap for Postgres:

```conf
host all all 0.0.0.0/0 scram-sha-256
```

### **Phase 5 — Roll the Cluster Safely**

```bash
kubectl edit kubegres mydb   # disable failover
kubectl rollout restart statefulset/mydb
kubectl edit kubegres mydb   # re-enable failover
```

### **Phase 6 — Post-Migration Validation**

* Pgpool connects successfully
* Apps connect successfully
* No MD5 hashes remain
* PostgreSQL logs show SCRAM authentication

---

# 10. **Conclusion**

Upgrading PostgreSQL authentication from MD5 to SCRAM-SHA-256 brings:

* Stronger password protection
* Better resistance to network threats
* Compliance with PostgreSQL 18’s future requirements
* Compatibility with Pgpool, PgBouncer, and Kubernetes
* Zero downtime during migration

Given MD5’s upcoming removal, now is the ideal time to transition — and thanks to PostgreSQL’s mixed-mode support, the process is smooth, safe, and operationally easy.

