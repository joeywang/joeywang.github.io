---
layout: post
title:  "Mastering Redis Memory Management with Microserver and Sidekiq"
date:   2024-07-01 14:41:26 +0100
categories: Rails
---
**Mastering Redis Memory Management with Microserver and Sidekiq**

**Introduction:**
Microservers have become increasingly popular due to their flexibility and ease of deployment and testing. However, they also present challenges, particularly with memory management in services like Redis. In this article, we'll explore a real-world scenario where Redis memory usage spiked dramatically and the steps taken to regain control.

**The Challenge: Redis Memory Surge**
Recently, I encountered a significant increase in Redis memory usage, jumping from 130MB to 800MB. Initially, I suspected the Redis cache was the culprit.

**Redis Memory Inspection**
Upon inspection with the `INFO memory` command, the memory usage was as follows:
```plaintext
used_memory:843019880
used_memory_human:803.97M
used_memory_rss:902520832
used_memory_rss_human:860.71M
```

**Redis Configuration Review**
I referred to the Redis documentation on eviction policies and found that the `maxmemory` and `maxmemory-policy` were not configured properly:
```bash
CONFIG GET maxmemory
1) "maxmemory"
2) "0"

CONFIG GET maxmemory-policy
1) "maxmemory-policy"
2) "noeviction"
```

**Setting Memory Limits**
To prevent further memory overruns, I set a memory limit and an eviction policy:
```bash
CONFIG SET maxmemory 1024m
CONFIG SET maxmemory-policy volatile-lru
```
*Note: Never set `maxmemory` to a value less than the current usage, as it can cause immediate service denial.*

**Digging Deeper**
A deeper investigation using `info keyspace` revealed a staggering number of keys, particularly in one database:
```plaintext
db0:keys=34,expires=0,avg_ttl=0
db1:keys=754,expires=719,avg_ttl=0
db2:keys=8924,expires=8864,avg_ttl=0
db3:keys=117156,expires=117140,avg_ttl=0
```
This pointed to an excess of Sidekiq jobs.

**The Sidekiq Overflow**
A month prior, an integration between App A and App B was implemented, which indexed active users and updated details. Lack of Sidekiq concurrency control led to thousands of requests, causing a memory spike.

**Strategies for Avoidance**
To prevent such overflows, consider the following:
1. **Sidekiq Limit**: Control the number of concurrent jobs per queue.
2. **Sidekiq Throttle**: Restrict the number of jobs processed within a given period.

I opted for throttling but underestimated the impact, leading to an ever-growing queue and increased memory consumption.

**Lessons Learned**
1. Sidekiq is powerful, but indiscriminate use is not a solution.
2. Sidekiq jobs require intelligent management.
3. Sidekiq queues need better orchestration.

**The Solution**
1. Adjust parameters to suit the workload.
2. Prevent duplicate jobs to ensure only necessary user information is processed.
3. Utilize Sidekiq's unique-job feature to avoid redundancies.

**Further Considerations**
1. Implement circuit breakers for future resilience.
2. Optimize data retrieval to pull only updated information.
3. Ensure App A returns only essential data.
4. Consider using webhooks from App A to push changes to App B, eliminating the need for pulls.

**Conclusion:**
Proper management of Redis and Sidekiq is crucial for maintaining performance and preventing memory overflows. By understanding and applying the right configurations, limits, and strategies, you can ensure a smoother and more efficient operation of your microservices architecture.
