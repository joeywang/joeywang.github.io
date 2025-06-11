# Designing Microservices with Proper Data Boundaries: Why Shared Databases Are a Code Smell

When building microservices, it's common to start with simplicity: multiple services reading and writing to the same database. But over time, this creates tight coupling, fragile integrations, and hidden data contracts. In this article, we explore why sharing databases across services is a code smell, and how to improve or evolve your architecture with clean boundaries, APIs, and events.

---

## 📊 The Problem: Shared Database Between Services

Imagine two Python applications:

- **App A** exposes API endpoints to serve data to users
- **App B** processes SQS messages and updates the database

Both read and write to the same database tables, using duplicated ORM models.

### What's Wrong with This?

| Issue                        | Description |
|-----------------------------|-------------|
| 🔄 Tight coupling          | A schema change in B can silently break A |
| 🌀 Hidden contracts         | No formal API or expectations between A and B |
| 😓 Migration friction      | DB schema changes are risky and disruptive |
| 🤖 Testing challenges      | Integration testing becomes fragile |
| 📈 Scalability limitations | Shared load and contention on the same DB |

### Code Smell Example

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

Even if both are correct today, any future drift will break assumptions in subtle ways.

---

## 💼 Solution: Clean Service Boundaries

### Step 1: Extract Shared ORM into a Library

Move ORM model definitions to a shared package:

```
shared_models/
  db.py
  models/
    user.py
```

Now both services import from the same source:

```python
from shared_models.models.user import User
```

This reduces duplication and ensures consistency.

---

### Step 2: Define Ownership and Access Rules

| Table      | Owned by | Accessed by |
|------------|----------|--------------|
| `users`    | App B    | App A (read-only) |
| `messages` | App B    | App B only |

Each service should only **write to its own tables**, or use views/roles to enforce read-only access.

---

### Step 3: Evolve Toward API Boundaries

Instead of reading directly from the DB, App A can call App B via API:

```text
[ App A ] -> [ App B API ] -> [ App B DB ]
```

This creates an explicit contract and allows App B to evolve internally.

#### Sample FastAPI Endpoint (App B)
```python
@app.get("/users/{user_id}")
def get_user(user_id: int):
    user = session.query(User).filter_by(id=user_id).first()
    return user
```

---

### Step 4: Consider an Event-Driven Architecture

Use events for communication instead of shared DBs:

```text
[ App B ] -> publishes "user.created" -> [ App A subscribes ]
```

- B owns the truth and publishes events
- A builds its own read model from events

This allows true decoupling and better scalability.

---

## ✅ When Shared DB Is Acceptable

If you're early in development or working within a monorepo, shared DB access can be a temporary convenience. Just follow these safeguards:

- Use a **shared model library**
- Define **clear table ownership**
- Write **contract-level integration tests**

---

## 🚀 Final Thoughts

If your microservices communicate via a shared DB, it's a sign to reevaluate boundaries. Move toward clear contracts, APIs, and events — you'll reduce fragility, increase team autonomy, and improve scalability long-term.

Need help refactoring your services or designing an event-driven layer? Reach out and let’s chat!

