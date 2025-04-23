---
layout: post
title: Debugging Transaction Deadlocks in Rails Tests: A Case Study
date: "2025-03-15"
categories: rails deadlock queue jobs
---

# Debugging Transaction Deadlocks in Rails Tests: A Case Study

In this article, we walk through a subtle and frustrating issue that can occur when running Rails tests involving ActiveJob and ActiveStorage. We'll explain how certain job queue modes can result in deadlocks, why it happens, how we diagnosed it, and best practices to avoid these pitfalls in the future.

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

Sometimes the transaction would stall right after beginning. We knew something was blocking—but what?

## Reproducing the Issue

This issue consistently occurred in tests that triggered background jobs, such as:

```ruby
test 'email attachments are processed' do
  email = emails(:example)
  email.process_attachments! # triggers background job
end
```

When run individually, the test passed. When run in a suite, it would hang.

## Investigating Further

We enabled full database logging and saw a pattern:

- The test starts a DB transaction (`BEGIN`)
- A job is enqueued that reads or updates the same records
- The job stalls, likely waiting on a lock held by the test

We wanted to know **where** the blocking was happening in Ruby code, so we added this helper:

```ruby
ActiveSupport::Notifications.subscribe('sql.active_record') do |_, _, _, _, payload|
  Rails.logger.debug caller.join("\n") if payload[:sql] =~ /TRANSACTION|SAVEPOINT/
end
```

This gave us a Ruby stack trace for each transaction, confirming that the blocking occurred inside background jobs.

## The Root Cause: Background Jobs + Transactions

By default, Rails uses `use_transactional_tests = true`, meaning each test runs inside a transaction. This is great for test speed and isolation.

However, job workers like `:async`, Sidekiq, or custom queues run in separate threads or processes. They can't see the data inside the test transaction since it's not committed.

So if your job tries to:

- Read the test-created record
- Update the same row

...it can **block waiting for a lock** or fail entirely. Worse, if both sides hold locks, you can hit a **deadlock**.

## The Fix: Use `:inline` Job Queue in Tests

We resolved the issue by configuring the test suite to run jobs synchronously:

```ruby
# test/test_helper.rb
Rails.application.config.active_job.queue_adapter = :inline
```

This ensures:

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

ActiveStorage uses polymorphic associations and triggers internal transactions. If you're creating or attaching files inside a transaction, you may also run into locks or deadlocks.

Keep your jobs simple and defer heavy DB writes until after the transaction is committed, or ensure all side effects happen inline during tests.

## Best Practices

1. **Use `:inline` queue adapter for tests** unless you're explicitly testing async behavior.
2. **Avoid enqueuing jobs in tests that use `use_transactional_tests = true`** unless the jobs are safe.
3. **Use logs and backtraces to track where the DB gets locked**.
4. **Isolate external effects** (e.g., file attachments, API calls) in jobs or services that are easy to test.

## Conclusion

Deadlocks and blocking in Rails tests can be tricky to debug. Understanding how transactions interact with job processing helps you design more predictable and stable test suites. When in doubt, keep your test jobs `:inline`, use logs, and track down those silent savepoints!

Happy debugging!

