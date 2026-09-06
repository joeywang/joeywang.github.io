---
layout: post
title: "Catching Database Configuration Drift Between Microservices"
description: "Two services sharing a database can pass every test and still fail in production if their DB configuration silently drifts apart."
date: "2025-02-11"
categories: [Database, DevOps]
tags: [testing, database, devops, ci]
---

<audio controls preload="metadata" src="/assets/audio/db-config-test-summary.ogg">
  Your browser does not support the audio element.
</audio>

Two services that share a database look like they're working together correctly, right up until their configuration quietly drifts apart. All the unit and integration tests can pass while the actual systems in production are talking to different databases entirely.

## The scenario

- App A exposes an HTTP API and reads from the database.
- App B processes messages (from SQS, say) and writes to the same database.

They communicate indirectly through that shared state. The assumption: if App B writes a row, App A will return it to users. That only holds if both are actually connected to the same database.

## The failure tests don't catch

In dev, CI, and staging you might have all of this passing:

- Unit tests in App A: "it returns data from the DB"
- Unit tests in App B: "it writes data correctly to the DB"
- Integration tests against mocked DBs

And in production, App A connects to `DB_A`, App B connects to `DB_B`. App B's writes never show up in App A. Because it's a configuration problem rather than a business logic bug, it's the kind of thing that's easy to introduce during a deploy and easy to miss entirely, since nothing in the code changed.

## Making the assumption testable

Testing logic isn't enough here. You need to validate deployment-time assumptions directly.

**Assert both services see the same data in CI.** With a shared `.env.test` or secret config, write from one side and read from the other:

```python
# App B test writes a user
session.add(User(id=1, name="Alice"))
session.commit()

# App A test reads the user
user = session.query(User).filter_by(id=1).first()
assert user.name == "Alice"
```

**Use one shared secret store in production.** AWS Secrets Manager, GCP Secret Manager, or Vault, so both A and B read credentials from the same source instead of two configs that can drift independently.

**Add a DB fingerprint check at startup.** A query like `SELECT current_database(), inet_server_addr();`, or a small table:

```sql
CREATE TABLE env_fingerprint (
  id INT PRIMARY KEY,
  environment TEXT,
  instance_id TEXT
);
```

Each service checks it on boot and refuses to start (or at least alerts loudly) if the fingerprint doesn't match what's expected.

**Expose DB identity on a health endpoint**, so you can diff it across services at any time:

```json
{
  "db_instance": "prod-db-001",
  "env": "production"
}
```

**Run a synthetic runtime check.** App B writes a known record, App A tries to read it within a short window, and the check fails loudly if it doesn't show up. This is the one that actually validates the contract is holding, not just that it held at deploy time.

**Watch DB access patterns in your observability platform**, and alert on connections from services that shouldn't be there.

Tests verify logic. They don't verify that the infrastructure your logic depends on is wired up the way you assumed. If your architecture relies on an implicit contract like a shared database, make that contract explicit and testable, or it will eventually fail silently and cost you a debugging session that has nothing to do with your code.
