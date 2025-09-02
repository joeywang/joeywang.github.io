---
layout: post
title: "Observer Pattern in Python: From Prototype to Productio"
date: 2025-06-22
categories: [observer, pattern]
tags: [design]
---
# Observer Pattern in Python: From Prototype to Production

**Subtitle:** Evolving from a single callback to a small event system without over‑engineering.

## Why this article

You’ve built a prototype with `state.update_state(new_state)` followed by `reporter.report(state)`. It works—until you forget to call `report()`, or you need to react to validation warnings, or you want multiple listeners. This guide shows a pragmatic path from a minimal observer to a maintainable event flow, highlighting trade‑offs between simplicity and extensibility.

## TL;DR

* Start with **one callback** and a **dataclass payload**.
* Return **`unsubscribe()`** from `subscribe()` and **iterate over a copy** during notify.
* When you need more than one topic, add **`EventKind`** and **`subscribe_kind`**, but keep `subscribe()` as a **compat shim**.
* For policy (e.g., "report only when no blocking errors"), add a **tiny orchestrator** rather than hard‑coding policy into state or reporter.

---

## Phase 1 — The Minimalist (today)

**Goal:** One thing happens → one callback fires. No bus, no topics.

**Why:** Fast to ship; minimal cognitive load; works for prototypes.

```python
from dataclasses import dataclass
from typing import Callable, List, Dict, Any

@dataclass(frozen=True)
class StateChanged:
    snapshot: Dict[str, Any]
    reason: str = "update"

class AppState:
    def __init__(self, initial: Dict[str, Any] | None = None) -> None:
        self._data = dict(initial or {})
        self._subs: List[Callable[[StateChanged], None]] = []

    def subscribe(self, fn: Callable[[StateChanged], None]) -> Callable[[], None]:
        self._subs.append(fn)
        def unsubscribe() -> None:
            try: self._subs.remove(fn)
            except ValueError: pass
        return unsubscribe

    def update_state(self, new_state: Dict[str, Any], *, reason: str = "update") -> None:
        self._data = dict(new_state)
        ev = StateChanged(snapshot=dict(self._data), reason=reason)
        for fn in list(self._subs):  # iterate over a copy
            try: fn(ev)
            except Exception: pass
```

**Trade‑offs:**

* ✅ Small surface area; dead‑simple to test.
* ⚠️ Only one event type; reporting rules can creep into `AppState` if you’re not careful.

**Best practice checklist:** dataclass event payload, `unsubscribe()`, copy iteration, never let one bad listener crash others.

---

## Phase 1.5 — Naming the Thing You Have

**Goal:** Formalize the single topic so you can add more later without breakage.

```python
from enum import Enum, auto

class EventKind(Enum):
    STATE_CHANGED = auto()  # only one—so far

class AppState:
    ...
    def subscribe_kind(self, kind: EventKind, fn):
        if kind is not EventKind.STATE_CHANGED:
            raise ValueError("unknown kind")
        return self.subscribe(fn)  # back‑compat alias
```

**Why:** New code can be explicit (`subscribe_kind(EventKind.STATE_CHANGED, ...)`) while old code keeps working.

---

## Phase 2 — Multiple Topics Without a Framework

**Goal:** Add validation issues alongside state changes; keep the API stable.

```python
from collections import defaultdict
from dataclasses import dataclass
from enum import Enum, auto
from typing import Any, Callable, Dict, List

class EventKind(Enum):
    STATE_CHANGED = auto()
    VALIDATION_ISSUE = auto()

@dataclass(frozen=True)
class ValidationIssue:
    field: str
    message: str
    blocking: bool = True  # False → non‑blocking warning
    severity: str = "error"

class AppState:
    def __init__(self, initial=None) -> None:
        self._data = dict(initial or {})
        self._subs: Dict[EventKind, List[Callable[[Any], None]]] = defaultdict(list)

    def subscribe_kind(self, kind: EventKind, fn: Callable[[Any], None]):
        self._subs[kind].append(fn)
        def unsubscribe():
            try: self._subs[kind].remove(fn)
            except ValueError: pass
        return unsubscribe

    # Back‑compat shim for Phase 1 callers
    def subscribe(self, fn: Callable[[Any], None]):
        return self.subscribe_kind(EventKind.STATE_CHANGED, fn)

    def _publish(self, kind: EventKind, ev: Any):
        for fn in list(self._subs[kind]):
            try: fn(ev)
            except Exception: pass

    def update_state(self, new_state: Dict[str, Any], *, reason: str = "update") -> None:
        self._data = dict(new_state)
        self._publish(EventKind.STATE_CHANGED, StateChanged(snapshot=dict(self._data), reason=reason))
        self._run_validation()

    def _run_validation(self) -> None:
        if not self._data.get("db.host"):
            self._publish(EventKind.VALIDATION_ISSUE, ValidationIssue(field="db.host", message="empty host"))
        if self._data.get("report.format") not in {"json", "text"}:
            self._publish(EventKind.VALIDATION_ISSUE, ValidationIssue(
                field="report.format", message="unknown; defaulting to json", blocking=False, severity="warning"))
```

**Trade‑offs:**

* ✅ Still lightweight; multiple listeners per topic.
* ⚠️ Slightly more ceremony; you must decide where validation lives.

**Best practice:** keep validation **decoupled** from `Reporter`—publish issues as events; let listeners decide.

---

## Phase 3 — Add Policy Without Tangling (Orchestrator)

**Goal:** Decide *when* reporting should proceed (e.g., only if no blocking issues) without hard‑coding that policy into `AppState` or `Reporter`.

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class ReportReady:
    snapshot: Dict[str, Any]

class Orchestrator:
    def __init__(self, state: AppState):
        self._latest = None
        self._has_blocker = False
        state.subscribe_kind(EventKind.STATE_CHANGED, self._on_state)
        state.subscribe_kind(EventKind.VALIDATION_ISSUE, self._on_issue)
        self._publish = state._publish  # reuse publisher; or inject a small bus

    def _on_state(self, ev: StateChanged):
        self._latest = ev.snapshot
        self._has_blocker = False  # reset per state

    def _on_issue(self, issue: ValidationIssue):
        if issue.blocking:
            self._has_blocker = True
        if self._latest and not self._has_blocker:
            self._publish(EventKind.STATE_CHANGED, ReportReady(snapshot=self._latest))
```

**Trade‑offs:**

* ✅ Policy is isolated; easier to test and reason about.
* ⚠️ Another moving part, but your state and reporters stay simple.

---

## Concurrency: sync vs. `asyncio`

* **Sync callbacks (default):** simplest; run in the caller thread. Use this until you truly need async.
* **Threaded emitters:** push events to a `queue.Queue` and have a single consumer thread dispatch to listeners.
* **Async:** swap the subscriber callbacks to `async` and feed an `asyncio.Queue`; a background task `await`s and dispatches.

**Rule of thumb:** Only go async when I/O dominates or you need back‑pressure.

---

## Error handling & resilience

* Catch exceptions **per listener** so one bad reporter doesn’t break others.
* Consider optional **logging hooks** that capture event kinds and latencies.
* For noisy updates, **debounce** (timer) or **coalesce** (batch) before publishing.

---

## Memory management

* For short‑lived observers, consider `weakref.WeakSet` (object observers) or store **only callables** and depend on `unsubscribe()`.
* Always offer `unsubscribe()` from day one; it’s the cheapest leak‑prevention tool.

---

## API stability & evolution

* Prefer **dataclasses** for event payloads (additive fields are non‑breaking).
* Keep `subscribe(cb)` as a **forever‑green alias** for `STATE_CHANGED` while new code uses `subscribe_kind`.
* If you adopt a library later (e.g., signals/event bus), **wrap it** behind the same `subscribe_kind` API to avoid ripples.

---

## Testing strategy

* **Unit test**: publish fake events and assert reporter/orchestrator reactions.
* **Property test**: random sequences of updates/issues shouldn’t deadlock and should never skip `unsubscribe()`d listeners.
* **Contract test**: ensure new fields in event payloads don’t break old reporters.

---

## When *not* to use observers

* If there’s exactly one consumer and always in lock‑step, a direct call is simpler.
* If ordering, retries, and delivery guarantees matter, consider a job queue (e.g., Celery) or a state machine library.

---

## Migration playbook (copy/paste)

1. Add `subscribe(cb)` to `AppState` and emit `StateChanged` (Phase 1).
2. Introduce `EventKind` + `subscribe_kind` and keep `subscribe()` as an alias (Phase 1.5).
3. Publish `ValidationIssue` events; keep `Reporter` unchanged initially (Phase 2).
4. Add an `Orchestrator` to enforce reporting policy (Phase 3).
5. Optional: extract a tiny `EventBus` for reuse across modules.

---

## Final thoughts

Design for **today** but make **tomorrow cheap**. A single callback with a dataclass gets you moving. A gentle path to topics and an optional orchestrator keeps complexity proportional to your needs—so you never have to choose between extensibility and simplicity again.

