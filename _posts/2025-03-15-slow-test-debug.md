---
layout: post
title: "Debugging Transaction Deadlocks in Rails Tests: A Case Study"
date: "2025-03-15"
categories: rails deadlock queue jobs
---

# Debugging Transaction Deadlocks in Rails Tests: A Case Study

This was one of those Rails test failures that wastes hours because it does not fail in a satisfying way.

The suite would hang. A single test might pass on its own. Then the full run would stall somewhere inside a transaction and leave behind just enough logging to be irritating.

The actual problem was the interaction between Rails test transactions, ActiveJob, and ActiveStorage.

Here is what the failure looked like, how I tracked it down, and the fix that made the suite boring again.

## The Symptom: Tests Get Stuck or Timeout

In a Rails application using ActiveStorage and background jobs, we noticed some MiniTest specs were hanging indefinitely. Debug logging showed that the database transaction began but never committed or rolled back:

```ruby
TRANSACTION (0.1ms)  BEGIN
Email Load (0.2ms)  SELECT ...
TRANSACTION (0.2ms)  SAVEPOINT active_record_1
Email Update (0.5ms)  UPDATE ...
TRANSACTION (0.5ms)  RELEASE SAVEPOINT active_record_1
... (other SELECTs)
TRANSACTION (0.5ms)  ROLLBACK
```

Sometimes the transaction would stall right after beginning. So something was blocking. The question was where.

## Reproducing the Issue

This issue kept showing up in tests that triggered background jobs, for example:

```ruby
test 'email attachments are processed' do
  email = emails(:example)
  email.process_attachments! # triggers background job
end
```

Run by itself, the test passed. Run in the suite, it could hang.

## Investigating Further

Once I turned on full database logging, a pattern showed up:

- The test starts a DB transaction (`BEGIN`)
- A job is enqueued that reads or updates the same records
- The job stalls, likely waiting on a lock held by the test

At that point I wanted to know **where** the blocking was happening in Ruby code, so I added this helper:

```ruby
ActiveSupport::Notifications.subscribe('sql.active_record') do |_, _, _, _, payload|
  Rails.logger.debug caller.join("\n") if payload[:sql] =~ /TRANSACTION|SAVEPOINT/
end
```

That gave me a Ruby stack trace for each transaction and confirmed that the blocking was happening inside background jobs.

## The Root Cause: Background Jobs + Transactions

By default, Rails uses `use_transactional_tests = true`, so each test runs inside a transaction. That is great for speed and isolation.

The catch is that job workers like `:async`, Sidekiq, or custom queues run in separate threads or processes. They cannot see the data inside the test transaction because it is not committed yet.

So if your job tries to:

- Read the test-created record
- Update the same row

...it can **block waiting for a lock** or fail outright. And if both sides hold locks, you can get a real **deadlock**.

## The Fix: Use `:inline` Job Queue in Tests

The fix was simple once the cause was clear: run jobs synchronously in tests.

```ruby
# test/test_helper.rb
Rails.application.config.active_job.queue_adapter = :inline
```

That gives you a few useful things:

- Jobs run immediately, in the same thread
- They share the same DB transaction context
- No risk of race conditions or visibility issues

You can also scope this change to a specific test:

```ruby
around do |test|
  original = ActiveJob::Base.queue_adapter
  ActiveJob::Base.queue_adapter = :inline
  test.call
ensure
  ActiveJob::Base.queue_adapter = original
end
```

## Bonus Pitfall: ActiveStorage + Transactions

ActiveStorage adds its own fun here because attachments can trigger extra internal transactions. If you are creating or attaching files inside a transaction, you can end up with even more chances to block.

The practical rule is simple: keep jobs simple, defer heavy DB writes until after commit when you can, or make the side effects happen inline in tests.

## Best Practices

1. **Use `:inline` queue adapter for tests** unless you're explicitly testing async behavior.
2. **Avoid enqueuing jobs in tests that use `use_transactional_tests = true`** unless the jobs are safe.
3. **Use logs and backtraces to track where the DB gets locked**.
4. **Isolate external effects** (e.g., file attachments, API calls) in jobs or services that are easy to test.

## Conclusion

Rails deadlocks in tests are annoying because they often look random until you notice the transaction boundary.

If a test touches background jobs and database state at the same time, I now assume queue mode is part of the problem until proven otherwise. In practice, `:inline` is usually the boring fix, and boring is exactly what you want from a test suite.
