---
layout: post
title: "Handling Out-of-Order Updates in Async Rails Workflows"
description: "When async updates to the same record can finish in any order, the oldest write can silently overwrite the newest one; here is how to stop that."
date: "2025-02-16"
categories: [Rails, Engineering]
tags: [rails, ruby, redis, database]
---

<audio controls preload="metadata" src="/assets/audio/out-of-order-updates-summary.ogg">
  Your browser does not support the audio element.
</audio>

If two updates to the same record are triggered in quick succession and processed asynchronously, nothing guarantees they finish in the order they were sent. If the earlier one finishes last, it overwrites the newer data with stale data, and the record ends up wrong with no error anywhere in the logs. This shows up constantly in event-driven systems, webhooks, mobile clients with retry logic, and background job workers.

Take a `Book` record updated twice in a row: `title: "First Draft"`, then `title: "Final Title"`. If they're queued and the first job happens to run second, `"Final Title"` gets clobbered back to `"First Draft"`. The fix depends on how strict the ordering guarantee needs to be.

## Ordering at the queue: a FIFO per resource

Push updates for a given record onto a Redis list (`RPUSH book_updates:<book_id>`) and have a single worker, or a lock-protected consumer, pop and apply them in order (`LPOP`). This guarantees order and decouples producer from consumer, at the cost of extra infrastructure and a small processing delay. It's the right tool when strict ordering is a hard requirement, not a nice-to-have.

## Last-write-wins by timestamp

Attach a `client_timestamp` to each update and reject anything older than what's already stored:

```ruby
def update_if_newer(params)
  return if params[:client_timestamp] < book.last_synced_at

  book.update!(params.except(:client_timestamp))
  book.update!(last_synced_at: params[:client_timestamp])
end
```

Simple, and it works well for stateless APIs and mobile clients. It breaks down if client clocks drift or a retry replays an old timestamp, so it's a good default, not a guarantee.

## Optimistic locking

Rails' [built-in optimistic locking](https://guides.rubyonrails.org/active_record_querying.html#optimistic-locking) rejects a write based on stale data outright:

```ruby
book.update(title: "Final Title", lock_version: 2)
```

If another write already bumped `lock_version`, this raises `ActiveRecord::StaleObjectError` instead of silently applying. No Redis required, but you own the retry logic, and it's a better fit for concurrent user edits than for async job processing where there's no user around to retry.

## Locking per resource

A Redis lock keyed on the record ID (something like a `SemaphoreLockable` concern) ensures only one worker touches a given `Book` at a time. Combine it with the timestamp check above and you've closed off both the concurrent-write problem and the stale-write problem at once.

## The recommendation

For most async update problems, this combination covers it:

- A per-resource lock so only one worker updates a given record at a time
- A monotonic version or timestamp check so a stale write is rejected, not silently applied
- Idempotent processing (a request ID or command ID checked before the write) so retries can't double-apply

```ruby
def idempotent_update(book_id, title, request_id)
  return true if ProcessedRequest.exists?(request_id: request_id)

  Book.transaction do
    book = Book.find(book_id)
    book.update!(title: title)
    ProcessedRequest.create!(request_id: request_id)
  end
end
```

That's usually enough. Vector clocks, CRDTs, Lamport timestamps, and gossip protocols solve real problems too, but they're built for multi-writer distributed systems without a single source of truth, not for "which of these two Sidekiq jobs ran last." Reach for them when you're actually building that kind of system, not by default. A version column and a lock get you further, with far less code to maintain.
