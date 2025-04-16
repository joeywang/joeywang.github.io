---
layout: post
title: "Testing Beyond Business Logic: Catching Hidden Configuration Failures in Microservices"
date: "2025-02-11"
categories: test microservice DB configuration
---

# Testing Beyond Business Logic: Catching Hidden Configuration Failures in Microservices

In microservice architectures, it's easy to assume that two services sharing a database are inherently working together correctly. But that assumption can quietly break down due to one critical blind spot: **configuration drift**.

In this article, we’ll explore how services that *seem* to be working independently can fail silently when their **shared database configuration diverges**—even when all unit and integration tests pass. We'll also look at testing strategies to catch these issues before they hit production.

---

## 🤦‍♂️ The Scenario: Hidden Config Drift

Consider this setup:

- **App A** exposes an HTTP API to clients and reads data from the database.
- **App B** processes messages (e.g., from SQS) and writes data into the same database.

They rely on a **shared database** to communicate indirectly. The assumption is:

> If App B writes to the database, App A will return that data to users.

But here’s the catch: that only works **if both are connected to the same database**.

---

## ❌ The Failure That Tests Don't Catch

In development, CI, and staging, you may have:

- ✅ Unit tests in App A: "It returns data from DB"
- ✅ Unit tests in App B: "It writes data correctly into DB"
- ✅ Integration tests with mocked DBs

**All tests pass.** But in production:

- App A connects to **DB_A**
- App B connects to **DB_B**

Result: App B’s writes never show up in App A.

Worse, because this is a **configuration issue**, it's not part of any business logic — and is very easy to forget or miss.

---

## ⚡ Solution: Configuration-Level Testing and Safeguards

We need to go beyond testing logic and start validating **deployment-time assumptions**. Here’s how:

---

### ✅ 1. Test That A and B Are Using the Same DB in CI

- Use a **shared `.env.test`** or secret config
- Run **sanity tests** to ensure A and B see the same data:

```python
# App B test writes a user
session.add(User(id=1, name="Alice"))
session.commit()

# App A test reads the user
user = session.query(User).filter_by(id=1).first()
assert user.name == "Alice"
```

---

### 🔐 2. Use a Shared Secret Store in Production

Use AWS Secrets Manager, GCP Secret Manager, or Vault to store DB credentials. This ensures both A and B read from the same config source.

---

### 📉 3. Add a DB Fingerprint Check at Runtime

Create a known identifier in the DB:

```sql
SELECT current_database(), inet_server_addr();
```

Or create a fingerprint table:

```sql
CREATE TABLE env_fingerprint (
  id INT PRIMARY KEY,
  environment TEXT,
  instance_id TEXT
);
```

Each service validates this on startup.

---

### 🌐 4. Expose DB Info via Health Endpoints

Expose an internal `/env` or `/db-fingerprint` endpoint in both apps:

```json
{
  "db_instance": "prod-db-001",
  "env": "production"
}
```

Then compare them across services.

---

### ⌛ 5. Add Synthetic Runtime Checks

Run a periodic job or test that:

- App B writes a known record
- App A attempts to read it within a short window
- Fail + alert if it doesn't match

This validates that the communication contract is holding at runtime.

---

### 🔍 6. Monitor DB Access Patterns

Use database logs or observability platforms (Datadog, New Relic, etc.) to:

- Confirm both apps are connecting to the same DB
- Alert if unexpected access patterns appear

---

## 🚀 Final Thoughts

Tests are great at verifying business logic — but they don’t catch everything. If your architecture relies on implicit contracts like **shared database state**, you need to make those contracts **explicit and testable**.

Configuration drift is invisible until it breaks something critical. Don’t wait for your users to discover it — build in the tests that catch it first.

---

Want a checklist or template for fingerprint testing or CI setup? Let’s build it together.

