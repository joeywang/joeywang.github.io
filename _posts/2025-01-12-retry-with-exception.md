---
layout: post
title: "Retry Strategies in Ruby: Exceptions vs. Conditional Checks"
description: "Comparing Ruby retry patterns, exception-based retry, conditional checks, and exponential backoff, and when each keeps performance acceptable."
date: "2025-01-12"
categories: [Engineering]
tags: [ruby, performance, debugging]
---

<audio controls preload="metadata" src="/assets/audio/retry-with-exception-summary.ogg">
  Your browser does not support the audio element.
</audio>

Transient failures, a flaky external service, a database timeout, a dropped network call, need a retry strategy. Ruby's `retry` keyword makes exception-based retry easy to reach for, but exceptions carry a real performance cost, and reaching for them by default isn't always the right call.

## Exception-based retry

```ruby
def retry_method
  attempts = 0
  begin
    attempts += 1
    puts "Attempt #{attempts}"
    raise "An error occurred" if attempts < 5 # Simulating failure
    puts "Success!"
  rescue => e
    puts "Rescued: #{e.message}"
    sleep 1
    retry if attempts < 5 # Automatically retries
  end
end

retry_method
```

This is simple and keeps the retry logic inside one `begin...rescue` block. The costs: raising and rescuing an exception is slower than a conditional check, since it builds a stack trace every time, and an unguarded `retry` can loop forever if the attempt count isn't checked.

## Conditional checks for expected failures

When failure is a normal, expected outcome rather than an exceptional one, a loop with a condition avoids the exception overhead entirely:

```ruby
def retry_method
  5.times do |attempt|
    result = risky_operation
    if result
      puts "Success!"
      return result
    else
      puts "Attempt #{attempt + 1} failed, retrying..."
      sleep 1
    end
  end
  raise "Operation failed after 5 attempts"
end

def risky_operation
  rand > 0.8 # Simulates a success/failure scenario
end
```

No exception overhead, at the cost of writing the failure handling explicitly instead of leaning on `rescue`.

## Exponential backoff

Retrying immediately just hammers whatever already failed. Backing off the delay reduces load on the thing you're retrying against:

```ruby
def retry_method
  attempts = 0
  begin
    attempts += 1
    puts "Attempt #{attempts}"
    risky_operation
    puts "Success!"
  rescue => e
    puts "Error: #{e.message}"
    sleep (2**attempts) # Exponential backoff
    retry if attempts < 5
  end
end
```

The tradeoff is resolution time: if the failure is persistent, backoff makes you wait longer to find that out.

## The `retryable` gem

```ruby
require 'retryable'

Retryable.retryable(tries: 5, sleep: 2) do
  puts "Trying operation..."
  raise "Temporary failure" if rand < 0.8
  puts "Success!"
end
```

Cleaner and more configurable than hand-rolled retry logic, at the cost of one more dependency.

## Performance notes

Raising an exception builds a stack trace every time, which adds CPU cost and GC pressure under frequent failures. Avoid logging `e.backtrace` inside a retry loop unless you're actively debugging, it's expensive and rarely needed for every attempt. And always cap the number of retries, with a circuit breaker if the failure is likely to be persistent rather than transient.

## When to use which

Exceptions fit unexpected failures, network timeouts, database errors, the kind of failure that should genuinely interrupt control flow. Conditional checks fit expected failures, rate limits, status codes you already anticipate. Most systems end up using both: exceptions for the genuinely exceptional, checks for the routine, and backoff wrapped around either one once retries start hitting a service under load.
</content>
