---
title: "Shared Databases Between Microservices Are a Code Smell"
date: 2024-02-05
description: "When two services share one database, a schema change in either one can silently break the other, and here is how to split ownership with APIs or events."
tags: [microservices, database, architecture]
categories: [Engineering]
---

<audio controls preload="metadata" src="/assets/audio/share-db-structure-summary.ogg">
  Your browser does not support the audio element.
</audio>


When you build microservices, it's common to start simple: two apps reading and writing the same database tables. It works right up until it doesn't. A schema change in one service can silently break the other, and neither team can point to a document that says who owns what.

## The problem: two apps, one database

Take two Python services. App A serves an API to users. App B processes SQS messages and writes to the database. Both read and write the same tables, through their own, separately maintained ORM models:

```python
# app_a/models/user.py
class User(Base):
    __tablename__ = 'users'
    id = Column(Integer, primary_key=True)
    name = Column(String)
    status = Column(String)

# app_b/models/user.py (duplicated)
class User(Base):
    __tablename__ = 'users'
    id = Column(Integer, primary_key=True)
    name = Column(String)
    status = Column(String)
```

Both definitions are correct today. The risk is drift: someone adds a column in App B's migration and forgets App A has its own copy of this model. There's no contract between the two, just an assumption that the schema stays in sync.

The cost shows up gradually: a schema change in B can silently break A, integration tests get fragile because there's no boundary to mock, and both services compete for the same connections and locks under load.

## Clean service boundaries

### Extract the shared model into a library

Move the ORM definitions into one package both services import:

```
shared_models/
  db.py
  models/
    user.py
```

```python
from shared_models.models.user import User
```

This removes the duplication. It does not remove the coupling: both services still touch the same tables directly.

### Define ownership

| Table      | Owned by | Accessed by |
|------------|----------|-------------|
| `users`    | App B    | App A (read-only) |
| `messages` | App B    | App B only |

Each service should write only to tables it owns. Everything else goes through a view, a read-only role, or an API.

### Move to an API boundary

Instead of App A reading the database directly, it calls App B:

```
App A -> App B API -> App B DB
```

```python
@app.get("/users/{user_id}")
def get_user(user_id: int):
    user = session.query(User).filter_by(id=user_id).first()
    return user
```

Now App B can change its schema freely as long as the endpoint's contract holds.

### Or move to events

```
App B -> publishes "user.created" -> App A subscribes
```

App B owns the data and publishes what changed; App A builds its own read model from the events it cares about. This is more work to set up than an API call, but it decouples the two services from each other's uptime, not just their schema.

## When a shared database is still fine

Early in a project, or inside a monorepo where one team owns both services, sharing a database is a reasonable shortcut. It stops being reasonable once two teams, two deploy schedules, or two on-call rotations are involved. If you take the shortcut, keep three things in place: a shared model library so the schema is defined once, an explicit ownership table like the one above, and contract tests that fail when one side changes the shape of data the other side depends on.

The point of the API or event boundary isn't purity. It's being able to change one service without reading the other service's code first.
