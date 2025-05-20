---
layout: post
title: "From Rails to Laravel: A Story of Conquering Racing Updates and “Last Update Wins”"
categories: Rails
tags: [Rails, Laravel, Sidekiq, SQS]
date: "2025-01-03 21:34 +0000"
---
# From Rails to Laravel: A Story of Conquering Racing Updates and “Last Update Wins”

I still remember the day I first stumbled upon a peculiar bug in my Rails application. My team and I had built a service to handle a flood of status changes from our users—think toggling an “active” switch, or updating personal preferences. It felt so straightforward: whenever a user clicked a toggle in our web interface, the system would enqueue a job to update the user’s database record. Quick, easy, done—right?

But then we discovered the dreaded *“racing updates.”* It started with a bewildered user report. They swore they had turned off their “active” flag, but the UI insisted they were still active. Confused, we dug into the logs. Sure enough, there were two updates queued up in quick succession:

1. `active = true`  
2. `active = false`

Somehow, the **false** update got processed first, and then along came the **true** update, overriding the user’s intended final state. Everyone was scratching their heads, muttering, “But... how could the system not know which update was final?” It dawned on us that our background jobs (processed by Sidekiq in the Rails world) could run out of order or at the same time, each believing itself to be the truth.

## Discovering Sidekiq Gems: Unique and Throttled Jobs

My first reaction was to search for a solution in the Rails ecosystem. Luckily, with Sidekiq, there were at least two popular gems that everyone seemed to be talking about:

- **`sidekiq-unique-jobs`**  
- **`sidekiq-throttle`**

`sidekiq-unique-jobs` allowed me to enforce that only one job for a specific “resource key” ran at once. By setting a lock key (like a user’s ID), we could block subsequent jobs until the first one completed. This cured a lot of concurrency headaches—especially where we’d queue multiple identical tasks that did the same thing.

`sidekiq-throttle` was also a godsend whenever we had to limit how many jobs ran in a minute. If a user somehow spammed our app, or if an external service had API rate limits, we could throttle the job processing to avoid overload or hitting usage caps.

But while these gems were wonderful for ensuring uniqueness and throttling, there was still the deeper challenge: “What if two different updates come in? How do we make sure only the *latest state* actually persists?” In many cases, `sidekiq-unique-jobs` alone wasn’t enough, because we still wanted to allow multiple updates... we just didn’t want older updates to overwrite newer ones.

### Versioning in Rails

I stumbled upon a neat pattern known as “optimistic concurrency.” Essentially, we’d keep a version number or timestamp in each record. We’d pass that version along to the job, and when the job tried to update the record, it would only succeed if the stored version was older. If some *newer* job had already updated the record, the old job’s attempt would silently fail. It was simple but powerful:

```ruby
User.where('version < ?', incoming_version)
    .update(active: active, version: incoming_version)
```

Problem solved. Or so I thought.

---

## Shifting to Laravel: The Concurrency Conundrum Returns

Fast forward a year. My team decided to build a new service in Laravel. “Piece of cake,” I thought. “We’ll just replicate the concurrency fixes we used in Rails.” But as soon as we started talking about queue processing in Laravel, someone asked: “What about those concurrency issues? Are there any gems like `sidekiq-unique-jobs` or `sidekiq-throttle` here?”

At first, I looked at my new Laravel project with a mixture of curiosity and concern—my beloved Sidekiq gems obviously wouldn’t work here. We needed to see what the Laravel ecosystem had to offer.

### Searching the Laravel Ecosystem

I discovered that Laravel, out of the box, had robust queue capabilities—supporting Redis, Amazon SQS, and others. It also offered [Laravel Horizon](https://laravel.com/docs/horizon) for real-time monitoring if we used Redis. But as I scanned the documentation, there wasn’t an immediate mention of “unique jobs” or “throttling” in the same sense as the Sidekiq gems.

A bit more sleuthing led me to two packages:

1. **[s-ichikawa/laravel-unique-jobs](https://github.com/s-ichikawa/laravel-unique-jobs)**
2. **[iya-kin/laravel-throttle-jobs](https://github.com/iya-kin/laravel-throttle-jobs)**

I was thrilled! They promised the same general functionality I’d grown accustomed to in Rails. But I wanted to test them before committing to a solution.

---

## 1. Stopping Duplicate Jobs with `laravel-unique-jobs`

Much like `sidekiq-unique-jobs`, `laravel-unique-jobs` let me define a “lock key” for my jobs. For example, if two different parts of the system tried to enqueue a job to update the *same user* in quick succession, I could choose to prevent that duplication.

```php
// Example job class
class UpdateUserStatus implements ShouldQueue
{
    use Uniqueable; // from the package

    protected $userId;
    protected $active;

    public function __construct($userId, $active)
    {
        $this->userId = $userId;
        $this->active = $active;
    }

    public function uniqueId()
    {
        return "update_user_status_{$this->userId}";
    }

    public function handle()
    {
        // ...
    }
}
```

With this approach, only *one* UpdateUserStatus job per user ID would be processed at a time. This helped if the **same** job was enqueued multiple times in a row. But it didn’t necessarily solve the problem where *two different updates* (like `active=true` versus `active=false`) might appear. If they shared the same lock key, the second job would simply wait until the first job completed, then proceed to run anyway. That was good for preventing collisions, but the *last update wins* issue was still lurking.

---

## 2. Throttling Through `laravel-throttle-jobs`

Sometimes, the bigger worry wasn’t uniqueness but the risk of *too many* jobs piling up. For instance, if a user toggled the same button 20 times in a minute, we didn’t need 20 job executions. We discovered [iya-kin/laravel-throttle-jobs](https://github.com/iya-kin/laravel-throttle-jobs), which let us define rules like:

- Only run **5** instances of a job per minute.  
- Never exceed **3** concurrent jobs of type XYZ at once.

It was reminiscent of `sidekiq-throttle`. By adding quick configuration in the job’s code, we could set these limits and let the package handle the locking mechanism behind the scenes (often using Redis). That solved the *“spammy toggle problem.”*

Yet, it still didn’t fully address the *versioning* or *last-update-wins* scenario.

---

## 3. Rolling Our Own: Cache Locks & Version Checks

Sometimes, no package precisely matches your needs—especially if you want granular control. We found that Laravel has built-in support for [Cache Locks](https://laravel.com/docs/cache#atomic-locks). The idea is that you can store a lock in Redis (or whichever cache driver you’re using) and try to acquire it before processing your job.

**Example**:

```php
use Illuminate\Support\Facades\Cache;

public function handle()
{
    $lock = Cache::lock('my_user_job:' . $this->userId, 5);

    if ($lock->get()) {
        try {
            // Do the update...
        } finally {
            $lock->release();
        }
    } else {
        // Could not acquire lock, skip or re-dispatch later
    }
}
```

This gave us a bit of “DIY uniqueness.” But that alone still doesn’t guard against the scenario where *different updates come in for the same user*, and you only want to finalize the most recent one.

### Adding Version/Timestamp

Here’s where the *optimistic concurrency pattern* reappears. By storing a `version` or `updated_at` timestamp on the user record, each job can carry that piece of data:

1. **Job**: “Set user #123 to `active=true`, version=5.”  
2. **DB Update**:  
   ```sql
   UPDATE users
   SET active = :active, version = :incoming_version
   WHERE id = :id
     AND version < :incoming_version
   ```

If the database version is 6 (meaning a *newer* update has already been applied), the old job’s update fails gracefully. It’s the ultimate “only the last update wins” solution. We used this with or without locks, depending on how strictly we needed concurrency control during the actual job execution.

---

## 4. Event-Sourcing: The Ultimate History Keeper?

During our explorations, we also encountered the idea of **event sourcing**. Instead of worrying about preventing old updates from overwriting new ones in the DB, we could log *every* state change in a time-ordered event stream. Then, a separate process (or read model) would figure out the final state by taking the last event. That’s overkill for many simple toggles, but in complex domains where you want an immutable history of changes, event sourcing can be a life-changer.

---

## 5. Our Final Recipe

1. **Uniqueness**: If we had a scenario where identical jobs would cause chaos, we’d reach for something like `laravel-unique-jobs` or a custom [Cache Lock](https://laravel.com/docs/cache#atomic-locks). This made sure we didn’t process the same job multiple times unnecessarily.

2. **Throttling**: For high-volume toggles or tasks that risked overwhelming our system, `laravel-throttle-jobs` was a straightforward solution to keep concurrency or rate-limits in check.

3. **Optimistic Concurrency**: To truly ensure only the last update stuck, we embedded a `version` or `updated_at` check in our database writes. This approach was as useful in Laravel as it was in Rails. That gave us peace of mind that no matter how updates arrived—out of order, delayed, or repeated—a newer version in the database would always prevail over older ones.

4. **Event-Sourcing**: Reserved for special use cases where we needed a robust audit trail and the ability to replay events. It’s a bigger architectural choice and not just a “quick fix.”

---

## Conclusion: Rails, Laravel, and the Universal Concurrency Problem

Moving from Rails (and Sidekiq) to Laravel taught me that concurrency issues—like “last update wins” or racing updates—are universal. Sure, the tooling might differ (`sidekiq-unique-jobs` vs. `laravel-unique-jobs`), but the underlying principle remains the same: if you’re pushing jobs to a queue that alter the same state, *you need a strategy to ensure the final database state is correct*.

For us, that strategy was a blend of:
- **Community packages** for uniqueness and throttling,  
- **Laravel’s built-in cache locks** for finer control,  
- **Version-based conditional writes** to guarantee “only the newest update matters.”

So, whether you’re a die-hard Rails developer or a Laravel enthusiast, remember: the concurrency beast lurks in every corner of asynchronous processing. But with the right tools—and a bit of storytelling about version numbers and locks—you can tame it before it devours your user’s final state.
