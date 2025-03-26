---
layout: post
title: "🛠️  API Design for Time Slot Replacement: Principles and Trade-offs"
date: "2025-01-10"
categories: api design refactoring
---

# 🛠️ **API Design for Time Slot Replacement: Principles and Trade-offs**

In modern booking systems, **time management** is a critical aspect. In scenarios like **online tutoring platforms**, tutors may occasionally need to replace their regular available slots with alternative ones due to vacations, personal commitments, or emergencies. When designing the API for such systems, we need to ensure that:
- Students never book an invalid time slot.
- The system maintains data consistency.
- Client-side caching does not display outdated or invalid slots.

---

## 🎯 **1. Problem Definition and Design Challenges**

In a **booking system**, we face the following challenges:
- Tutors define regular available time slots.  
- Tutors occasionally specify **alternative slots** to replace unavailable regular slots.  
- Students should only see valid time slots when querying availability.  
- Caching on the client side can lead to displaying stale or invalid slots.  

✅ **Design Objectives**
- Ensure students cannot book replaced slots.  
- Maintain data consistency, avoiding stale cache issues.  
- Provide a clean, scalable API design that is easy to maintain.  

---

## 🔍 **2. Design Principles and Trade-offs**

### ✅ **Principle 1: Server-Side Consistency First**
In scenarios involving time slot replacement, **consistency is key**. Therefore, the server should handle the replacement logic.  
**Why?**
- The server has a **global view** of the data and can accurately determine which slots are invalid.  
- Client-side caching may lead to **stale data** being displayed, causing booking errors.  
- Offloading replacement logic to the server reduces the complexity of client-side code.  

✅ **Conclusion:**
- The **server** should replace regular slots with alternative ones before returning the data.  
- The client only receives valid, conflict-free time slots.  

---

### 🚫 **Anti-Pattern: Client-Side Filtering**
**Alternative Approach:**  
- The server returns both regular and alternative slots.  
- The client filters out replaced slots based on a `is_replaced` flag.  

**Problems with this approach:**
- Increased client-side complexity.  
- Clients with stale cache may display invalid slots.  
- Consistency issues across multiple clients.  

✅ **Conclusion:**  
- The server should handle replacement logic to ensure **data consistency**.  
- The client only needs to display valid slots.  

---

## 🔥 **3. API Design and Implementation**

### ✅ **Database Schema**

We first design the database schema to store both regular and alternative slots.

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
- `is_replaced`: Marks the regular slot as replaced.  
- `alternative_start` and `alternative_end`: Store the replacement time range.  

---

### ✅ **API Design: Merging Alternative and Regular Slots**

**Goal:**  
- The server merges the **regular slots** with **alternatives** before returning the result.  
- Only valid slots are exposed to the client.  

📌 **SQL Query Example**
```sql
-- Query to return only valid time slots
SELECT 
    tutor_id,
    date,
    COALESCE(alternative_start, start_time) AS start_time,
    COALESCE(alternative_end, end_time) AS end_time
FROM tutor_availability
WHERE date = '2025-04-01' 
  AND (is_replaced = false OR (alternative_start IS NOT NULL AND alternative_end IS NOT NULL));
```

✅ **Result**
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

---

### ✅ **Server-Side Slot Merging Logic (Python Example)**

```python
def get_available_slots(tutor_id, date):
    slots = query_database(tutor_id, date)

    # Merge regular and alternative slots
    available_slots = []
    for slot in slots:
        if slot['is_replaced'] and slot['alternative_start'] and slot['alternative_end']:
            # Use alternative slots
            available_slots.append({
                "start_time": slot['alternative_start'],
                "end_time": slot['alternative_end']
            })
        elif not slot['is_replaced']:
            # Use regular slots
            available_slots.append({
                "start_time": slot['start_time'],
                "end_time": slot['end_time']
            })
    
    return available_slots
```

✅ **Explanation:**
- The server handles the merging logic.  
- It ensures only valid slots are returned to the client.  

---

### ✅ **Client-Side Caching Issue: Versioning Solution**

**Problem:**  
- Client-side caching can cause stale data to be displayed.  
- Students may book replaced slots due to outdated cache.  

**Solution:**  
- The server returns a **data version** alongside the time slots.  
- The client caches the version with the data.  
- On subsequent requests, the client sends the version.  
- If the version is outdated, the server forces a refresh.  

📌 **API Response with Versioning**
```json
{
  "version": "2025-04-01T10:00:00Z",   // Server-side version
  "available_slots": [
    {
      "start_time": "2025-04-01T10:30:00Z",
      "end_time": "2025-04-01T11:30:00Z"
    }
  ]
}
```

✅ **Client Logic**
- Cache the version and slots.  
- On the next request, compare the cached version with the server version.  
- If they differ, invalidate the cache and reload the data.  

---

## ⚙️ **4. Optimizations and Scalability**

### ✅ **① Redis Caching**
To reduce database queries, we cache the tutor’s availability slots in Redis.  
- Store the merged slots in Redis.  
- Invalidate the cache whenever slots are modified.  

📌 **Caching Logic**
```python
import redis

redis_client = redis.StrictRedis(host='localhost', port=6379, db=0)

def get_slots(tutor_id, date):
    cache_key = f"slots:{tutor_id}:{date}"

    # Check Redis cache first
    cached_data = redis_client.get(cache_key)
    if cached_data:
        return json.loads(cached_data)

    # Query the database
    slots = query_database(tutor_id, date)

    # Store in Redis for 10 minutes
    redis_client.setex(cache_key, 600, json.dumps(slots))
    
    return slots
```

✅ **Cache Invalidation**
- When the tutor modifies availability, invalidate the cache.  
- Use events or message queues to notify other nodes.  

---

### ✅ **② WebSocket Notifications**
To prevent students from seeing outdated slots, use **WebSockets** to push real-time updates.  
- When a tutor modifies their availability, send a notification to all connected clients.  
- Clients refresh the time slots instantly.  

---

### ✅ **③ Concurrency and Idempotency**
To prevent double bookings in high-concurrency scenarios:
- Use **idempotency keys** to avoid duplicate operations.  
- Ensure **transactions** for consistency.  

✅ **API with Idempotency**
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

---

## 🚀 **5. Conclusion and Best Practices**

✅ **Server-Side Consistency**
- Handle time replacement logic on the server.  
- Return only valid slots to the client.  

✅ **Cache with Versioning**
- Use a version field to avoid stale cache issues.  
- Invalidate outdated cache based on version mismatch.  

✅ **Optimizations**
- Redis caching for faster slot retrieval.  
- WebSocket notifications for real-time updates.  
- Idempotency to prevent double bookings.  

✅ **By handling time replacement on the server and applying cache versioning, you ensure data consistency, reduce complexity on the client, and provide a robust and scalable booking system.** 🚀
