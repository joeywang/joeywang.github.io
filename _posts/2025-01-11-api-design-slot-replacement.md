---
layout: post
title: "API Design for Time Slot Replacement in Booking Systems"
description: "How to design a booking API that replaces regular time slots with alternatives, using server-side merging, cache versioning, and idempotency keys."
date: 2025-01-11
categories: [Engineering]
tags: [api, redis, database, performance]
---

<audio controls preload="metadata" src="/assets/audio/api-design-slot-replacement-summary.ogg">
  Your browser does not support the audio element.
</audio>

An online tutoring platform, or any booking system, has to let a tutor swap a regular time slot for an alternative one, a vacation, a conflict, an emergency, without ever letting a student book the slot that's been replaced. That requirement touches three things at once: correctness of what the client sees, data consistency, and cache freshness.

## The design decisions

A tutor's regular availability and their occasional replacements both need to reach the student as one clean list of valid slots. Two places could own the logic that decides which slot wins when a replacement exists: the server, or the client.

**Server-side wins.** The server has the global view of the data; the client only has whatever it last fetched. If replacement logic lives on the server, the client always receives a conflict-free list and never has to reconcile two sources of truth.

The alternative, returning both regular and alternative slots and letting the client filter on an `is_replaced` flag, pushes that reconciliation onto every client, and a client with a stale cache will happily display an invalid slot. That's the actual failure mode this design has to prevent, so client-side filtering is the wrong default.

## Schema and query

```sql
CREATE TABLE tutor_availability (
    id SERIAL PRIMARY KEY,
    tutor_id INT NOT NULL,
    date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_replaced BOOLEAN DEFAULT false,         -- Indicates if the slot is replaced
    alternative_start TIME,                    -- Alternative time slot
    alternative_end TIME
);
```

The server merges regular and alternative slots before the response ever reaches the client:

```sql
SELECT
    tutor_id,
    date,
    COALESCE(alternative_start, start_time) AS start_time,
    COALESCE(alternative_end, end_time) AS end_time
FROM tutor_availability
WHERE date = '2025-04-01'
  AND (is_replaced = false OR (alternative_start IS NOT NULL AND alternative_end IS NOT NULL));
```

```json
{
  "tutor_id": "67890",
  "date": "2025-04-01",
  "available_slots": [
    {
      "start_time": "2025-04-01T10:30:00Z",
      "end_time": "2025-04-01T11:30:00Z"
    }
  ]
}
```

Or the same merge done explicitly in application code:

```python
def get_available_slots(tutor_id, date):
    slots = query_database(tutor_id, date)

    available_slots = []
    for slot in slots:
        if slot['is_replaced'] and slot['alternative_start'] and slot['alternative_end']:
            available_slots.append({
                "start_time": slot['alternative_start'],
                "end_time": slot['alternative_end']
            })
        elif not slot['is_replaced']:
            available_slots.append({
                "start_time": slot['start_time'],
                "end_time": slot['end_time']
            })

    return available_slots
```

Either way, the client never sees a replaced slot at all, there's no flag for it to get wrong.

## Cache freshness: version the response

Server-side merging solves correctness at read time. It doesn't solve a client holding a cached response from before a tutor changed their availability. Attach a version to the response:

```json
{
  "version": "2025-04-01T10:00:00Z",
  "available_slots": [
    {
      "start_time": "2025-04-01T10:30:00Z",
      "end_time": "2025-04-01T11:30:00Z"
    }
  ]
}
```

The client caches the version alongside the data and sends it back on the next request. A version mismatch tells the server the client's cache is stale and forces a reload, without the client needing to know why.

## Scaling it further

**Redis for the merged result**, so repeated reads for the same tutor and date skip the database entirely:

```python
import redis

redis_client = redis.StrictRedis(host='localhost', port=6379, db=0)

def get_slots(tutor_id, date):
    cache_key = f"slots:{tutor_id}:{date}"

    cached_data = redis_client.get(cache_key)
    if cached_data:
        return json.loads(cached_data)

    slots = query_database(tutor_id, date)
    redis_client.setex(cache_key, 600, json.dumps(slots))

    return slots
```

Invalidate that cache key the moment a tutor's availability changes, don't rely on the TTL alone.

**WebSocket notifications**, so connected clients refresh the moment a tutor changes availability instead of waiting for their next poll or cache expiry.

**Idempotency keys**, so a booking request retried by a flaky client or a double-click doesn't create two bookings:

```http
POST /api/bookings
Content-Type: application/json
Idempotency-Key: 123e4567-e89b-12d3-a456-426614174000
{
    "tutor_id": "67890",
    "date": "2025-04-01",
    "start_time": "10:30",
    "end_time": "11:30"
}
```

## The principle

Keep the replacement decision on the server, so the client only ever sees valid slots and never has to reconcile a flag. Version the response so a stale client cache gets forced to refresh rather than silently showing a slot that's already gone. Everything else, Redis, WebSockets, idempotency keys, is there to keep that guarantee fast and safe under concurrency, not to replace it.
</content>
