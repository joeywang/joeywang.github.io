---
layout: post
title: "Fixing Racing Background Job Updates: Rails to Laravel"
description: "How optimistic concurrency, unique job locks, and throttling stop out-of-order background job updates in both Rails/Sidekiq and Laravel queues."
categories: [Rails]
tags: [rails, sidekiq, laravel, aws]
date: 2025-01-04 21:34 +0000
---
<audio controls preload="metadata" src="/assets/audio/rails-racing-jobs-sidekiq-sqs-summary.ogg">
  Your browser does not support the audio element.
</audio>

We had a service that turned every toggle in the UI, an "active" flag, a preference change, into a queued job that updated the user's database record. Straightforward, until a user swore they had turned their "active" flag off and the UI kept showing them as active.

The logs explained it: two updates had been queued in quick succession.

1. `active = true`
2. `active = false`

The `false` update ran first, then the `true` update landed after it and overwrote the user's intended final state. Sidekiq made no promise that jobs run in the order they were enqueued, and once two jobs for the same record run out of order, each one believes itself to be the final word.

## Sidekiq: unique and throttled jobs

Two gems come up immediately in the Rails ecosystem: `sidekiq-unique-jobs` and `sidekiq-throttle`.

`sidekiq-unique-jobs` lets you lock on a resource key, a user's ID, so only one job for that key runs at a time. That killed a class of bugs where the same task got queued twice. `sidekiq-throttle` caps how many jobs run per minute, useful when a user spams a toggle or an external API has a rate limit.

Neither solves the actual problem. Uniqueness prevents the same job from running twice; it does not stop two *different* jobs, `active=true` and `active=false`, from running in the wrong order. If they share a lock key, the second job just waits for the first to finish, then runs anyway. Last write still wins, and it is not always the last write that was requested.

### Optimistic concurrency

The fix is a version number on the record. Each job carries the version it saw, and the update only applies if the stored version is older:

```ruby
User.where('version < ?', incoming_version)
    .update(active: active, version: incoming_version)
```

If a newer job already updated the row, the older job's write silently no-ops. Order of arrival stops mattering, only the version does.

## The same problem in Laravel

A year later, a different team built a new service in Laravel and asked the same question: does Laravel have anything like `sidekiq-unique-jobs` or `sidekiq-throttle`?

Laravel's queue layer supports Redis, SQS, and others out of the box, plus Horizon for monitoring on Redis. Neither uniqueness nor throttling is built in, but two packages cover the same ground:

- [s-ichikawa/laravel-unique-jobs](https://github.com/s-ichikawa/laravel-unique-jobs)
- [iya-kin/laravel-throttle-jobs](https://github.com/iya-kin/laravel-throttle-jobs)

### Unique jobs

```php
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

This gives one `UpdateUserStatus` job per user ID at a time, which stops the same job from being processed twice. It does not stop a second, different update from running once the first one clears the lock. Same limitation as `sidekiq-unique-jobs`.

### Throttling

`laravel-throttle-jobs` caps concurrency and rate, for example five instances of a job per minute, or no more than three concurrent jobs of a given type. It solves the spammy-toggle problem. It does not solve which update should win.

### Cache locks and version checks

Laravel's [atomic cache locks](https://laravel.com/docs/cache#atomic-locks) give the same DIY uniqueness the packages provide:

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

And the same version check from Rails closes the gap:

```sql
UPDATE users
SET active = :active, version = :incoming_version
WHERE id = :id
  AND version < :incoming_version
```

If the stored version is already 6 and this job carries version 5, the write fails, correctly. This is the actual fix, with or without a lock around it.

### Event sourcing, for the harder cases

If you need a full audit trail instead of just the current state, log every change as an event and derive current state from the last event in the stream. That is more machinery than a toggle needs, but for domains where history matters as much as the current value, it replaces the version check entirely.

## The principle

Uniqueness and throttling solve two real but different problems: don't run the same job twice, don't run too many jobs at once. Neither one guarantees that the last-applied update is the last-requested update. That guarantee comes from a version or timestamp check at the point of write, and it works the same way whether the queue underneath is Sidekiq or Laravel's queue driver. The tooling changes between frameworks; the concurrency problem does not.
</content>
