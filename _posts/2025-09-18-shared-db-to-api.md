---
title: "From Shared Database to APIs: Justifying the Move and Taming the
Performance Hit"
date: 2025-09-18
description: "How to mitigate latency when transitioning from a shared
database to an API-driven architecture."
tags: [architecture, performance, microservices, api, caching]
categories: [architecture, performance, microservices, api, caching]
layout: post
---

## From Shared Database to APIs: Justifying the Move and Taming the Performance Hit

Many growing engineering teams reach a crossroads. The architecture that got you off the ground—multiple services reading and writing to the same central database—becomes a bottleneck. It’s fast, simple, and... incredibly brittle.

A common "fix" is to decouple: the **Core Service** (which owns the "source of truth" data) exposes its data via a new, internal REST API. Other services, like a **BFF (Backend for Frontend) Service** that powers your mobile app, must now go through this API instead of talking to the database directly.

This is a huge step forward for long-term maintainability. But it comes at a cost.

You've just introduced a new network hop. What was once a sub-millisecond database query from your BFF Service is now a full-blown, network-bound API call.

`Mobile App -> BFF Service -> Core API -> Core Database`

That new arrow (`BFF Service -> Core API`) is the "network tax" you're paying for a healthier architecture. The question is not "Was this a mistake?" (it wasn't), but rather, "How do we aggressively mitigate this new cost?"

### ✅ First, Validate the Decision

Let's be clear: moving away from a shared database is almost always the correct long-term decision. You've traded raw, brittle performance for foundational benefits:

* **True Data Ownership:** The Core Service now *truly owns* its data. No other service can corrupt its state or bypass its business logic.
* **Decoupling & Independent Deployment:** The Core team can change its database schema, optimize queries, or refactor logic without breaking the BFF Service, as long as the API contract is maintained.
* **Scalability:** You can now scale the Core Service and the BFF Service independently. If the BFF is getting slammed with mobile traffic, you can scale its instances without having to scale the (potentially more stateful) Core Service.
* **Security:** Your database's attack surface is dramatically reduced. Access is now only possible through a hardened, validated API layer.

The performance hit is a known trade-off, and your job is to apply standard, high-leverage patterns to mitigate it.

---

### ⚡ Strategies to Tame the Latency Beast

Here are the most effective ways to optimize your new architecture, ordered by impact.

#### 1. Caching: Your First and Best Defense
This is the 80/20 solution. The API call from your BFF Service to the Core API is the *perfect* candidate for caching.

* **Where:** Implement a cache within the BFF Service.
* **How:** Use a distributed in-memory cache like **Redis** or **Memcached**.
* **The Flow:**
    1.  The mobile app requests data from the BFF Service.
    2.  The BFF Service first checks Redis for this data (using a well-defined key, e.g., `user:{id}:profile`).
    3.  **Cache Hit:** The data is in Redis. It's returned in sub-millisecond time. No API call is made to the Core Service.
    4.  **Cache Miss:** The data is not in Redis. The BFF Service makes the API call to the Core Service, gets the response, **stores that response in Redis** (with a set TTL, or Time-to-Live, like 5 minutes), and then returns it to the mobile app.

This one change can eliminate the vast majority of your new network latency for "read-heavy" traffic.

#### 2. Smarter API Design: The Facade Pattern
Your BFF Service is already a "Backend for Frontend," which is a specialized **Facade**. Its job is to provide a coarse-grained API perfectly tailored to your mobile app's *screens*.

* **The Problem ("Chatty" APIs):** Imagine your app's "Home" screen needs user data, their team data, and their latest stats. A naive approach would be:
    * Mobile App makes 1 call to BFF: `GET /home-screen`
    * BFF makes 3 calls to Core API:
        1.  `GET /users/{id}`
        2.  `GET /teams/{teamId}`
        3.  `GET /users/{id}/stats`
    This is a 1+N problem, and the latency adds up.
* **The Solution (Aggregated Endpoints):** Create a *new, single endpoint* on the Core API that does this work on the server side.
    * New endpoint on Core API: `GET /users/{id}/profile-summary`
    * This single endpoint gathers the user, team, and stats data *on the server* (where it has fast, local DB access) and returns it in one JSON payload.
    * Now your flow is: `Mobile (1 call) -> BFF (1 call) -> Core API (1 call)`. You've eliminated the extra network hops.

#### 3. Asynchronous Processing: Does It Need to Be *Now*?
Challenge every synchronous assumption. Does the user *really* need to wait for the Core API's response?

* **The Scenario:** A user makes a post. This post needs to be saved, and it also needs to update their "total posts" stat in the Core Service.
* **Synchronous (Slow) Way:**
    1.  Mobile `POST /post` to BFF.
    2.  BFF saves the post to its own DB.
    3.  BFF calls `PUT /users/{id}/stats` on the Core API.
    4.  BFF *waits* for the Core API to respond.
    5.  BFF returns "OK" to the mobile app.
* **Asynchronous (Fast) Way:**
    1.  Mobile `POST /post` to BFF.
    2.  BFF saves the post to its own DB.
    3.  BFF immediately returns "OK" to the mobile app (fast *perceived* performance).
    4.  BFF places a `{"userId": "123", "action": "incrementPostCount"}` message onto a **message queue** (like RabbitMQ or SQS).
    5.  A separate, background worker processes this message and makes the call to the Core API. The user is already on to their next task.

#### 4. Optimize the Network Path and Payload
Don't neglect the low-hanging fruit.

* **Colocation:** Are your BFF Service and Core Service running in the same cloud region and Virtual Private Cloud (VPC)? The latency between two services in `us-east-1a` should be < 2ms. If they are in different regions, you have a major, fixable problem.
* **Payload Size:** Don't send more data than you need. If the Core API's `GET /users/{id}` endpoint returns a massive object with 50 fields, but the BFF only needs 3 of them, you're wasting bandwidth and serialization time. Use filtering (e.g., `?fields=name,avatar`) or consider **GraphQL** for more advanced field selection.
* **Protocol:** For internal, server-to-server communication, text-based REST/JSON is easy but verbose. For high-performance, low-latency needs, consider **gRPC** with Protocol Buffers, a binary protocol designed for speed.

---

### Beyond Speed: Building for Resilience

Performance isn't just about speed; it's about reliability. What happens when your new Core API is slow or down?

* **Implement Circuit Breakers:** In your BFF Service, wrap your calls to the Core API in a **circuit breaker** (using libraries like Resilience4j or Polly). If the Core API starts failing, the circuit "opens," and the BFF Service will "fail fast" (e.g., return cached data or a graceful error) instead of hanging and cascading the failure to your mobile users.
* **Add Distributed Tracing:** You can't fix what you can't measure. Implement **distributed tracing** (e.g., OpenTelemetry, Datadog, New Relic). This will give you a flame graph for every single mobile request, showing you *exactly* where the time is being spent.
    * `Mobile -> BFF (Total: 450ms)`
        * `BFF Business Logic (25ms)`
        * `BFF -> Core API (Call: 400ms)`
            * `Core API -> Core DB (Query: 15ms)`
        * `BFF Logic (25ms)`

    With this view, the bottleneck (`BFF -> Core API`) becomes impossible to ignore.

### Conclusion

Moving from a shared database to an API-driven architecture is a crucial sign of engineering maturity. The initial performance hit is not a failure—it's a predictable, well-understood trade-off. By applying these layered optimization strategies, you can achieve the best of both worlds: a robust, decoupled, and maintainable system that is also highly performant for your users.
