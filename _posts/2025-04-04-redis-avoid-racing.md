---
layout: post
title: "Understanding Deadlocks in MySQL and PostgreSQL: Integrity vs Performance"
title: "Ensuring Idempotency with Semaphore Locks in Rails: Handling Concurrent Requests Efficiently"
date: "2025-04-04"
categories: database performance integrity
---

# **Ensuring Idempotency with Semaphore Locks in Rails: Handling Concurrent Requests Efficiently**

Concurrency issues in web applications, especially when dealing with race conditions, are common when multiple users or processes try to perform the same action at the same time. These issues often result in data inconsistencies, errors, or failures — especially when trying to enforce uniqueness, such as creating a new resource with a unique identifier (e.g., a UUID).

In this article, we'll explore how to address these problems in a **Ruby on Rails** application by using **semaphore locks**. We'll walk through a solution using **Redis-backed caching** to ensure that only one process or thread can access a critical section of code at a time, making the process **idempotent**.

---

## **The Problem: Race Conditions and Duplicate Requests**

Consider the following scenario: Your application needs to handle requests that create new resources, such as `LessonSession` records, identified by a unique `uuid`. In a highly concurrent environment, it's possible that multiple requests for the same `uuid` might come in simultaneously. If this happens, two records with the same `uuid` might be created, violating your database's unique constraint.

Here's a simplified version of the code that leads to a **`PG::UniqueViolation`**:

```ruby
def create
  lesson_session = LessonSession.find_or_initialize_by(uuid: permitted_params[:uuid])
  if lesson_session.persisted?
    head :no_content
    return
  end

  lesson_session.assign_attributes(permitted_params.merge(user: current_user))
  lesson_session.deactivate

  if lesson_session.save
    lesson_session.create_study_time!
    head :no_content
  else
    render json: lesson_session.errors, status: :unprocessable_entity
  end
end
```

In the code above, if two requests for the same `uuid` come in concurrently, they might both pass the check for the `persisted?` condition and try to save the same `LessonSession`, causing a **unique constraint violation**.

---

## **The Solution: Distributed Semaphore Locks**

To solve this problem, we can use a **distributed semaphore lock**. A **semaphore lock** allows only one process to access a critical section of code at a time. If another request tries to enter the critical section while the lock is held, it can either **wait** or **skip** the operation, depending on the use case.

In our case, we want to ensure that only one request can create a `LessonSession` for a specific `uuid` at a time. If another request comes in while the lock is held, we’ll simply skip it or return a `no_content` response.

We'll use **Rails.cache**, backed by Redis, to handle the locking mechanism. Redis is well-suited for this purpose due to its atomic operations, and Rails provides an abstraction layer (`Rails.cache`) that allows us to interact with it easily.

---

## **Implementing the Semaphore Lock**

We'll create a **concern** to wrap the lock logic into a reusable helper method that can be used across controllers, jobs, and services. The core idea is to use **`Rails.cache.write`** with `unless_exist: true` to acquire the lock, and **`Rails.cache.delete`** to release it.

Here’s how we implement the semaphore lock in a Rails concern:

### **SemaphoreLock Concern**

```ruby
# app/controllers/concerns/semaphore_lockable.rb
module SemaphoreLockable
  extend ActiveSupport::Concern

  # Runs the block only if the semaphore lock is acquired.
  # Yields :locked if lock is acquired, :skipped otherwise.
  def with_semaphore_lock(key, ttl: 10.seconds, namespace: "semaphore_lock")
    full_key = "#{namespace}:#{key}"
    acquired = Rails.cache.write(full_key, true, expires_in: ttl, unless_exist: true)

    if acquired
      begin
        yield :locked
      ensure
        Rails.cache.delete(full_key)
      end
    else
      yield :skipped
    end
  end
end
```

### **Explanation:**
1. **`with_semaphore_lock` method**:
   - It tries to acquire the lock by writing a key to the cache with an expiration time (`ttl`).
   - If the lock is acquired (the key didn’t exist), it runs the provided block and yields `:locked`.
   - If the lock is already held, it yields `:skipped`, allowing you to handle skipped requests appropriately.
   - After the block executes (or skips), it **releases the lock** by deleting the key.

2. **Parameters**:
   - `key`: The unique identifier (e.g., UUID or task identifier) used to create the lock.
   - `ttl`: The lock expiration time (default is 10 seconds).
   - `namespace`: A namespace for the lock key to avoid key collisions with other locks.

---

## **Using the Semaphore Lock in Your Controller**

Once we have our `SemaphoreLockable` concern, we can use it in any controller action where we need to protect a critical section.

### **Example Usage in Controller**

```ruby
class LessonSessionsController < ApplicationController
  include SemaphoreLockable

  def create
    uuid = permitted_params[:uuid]

    with_semaphore_lock("lesson_session:#{uuid}", ttl: 10.seconds) do |status|
      case status
      when :locked
        LessonSession.transaction(requires_new: true) do
          lesson_session = LessonSession.find_or_initialize_by(uuid: uuid)
          if lesson_session.persisted?
            head :no_content
            return
          end

          lesson_session.assign_attributes(permitted_params.merge(user: current_user, course: Current.course))
          lesson_session.deactivate

          if lesson_session.save
            lesson_session.create_study_time!
            head :no_content
          else
            render json: lesson_session.errors, status: :unprocessable_entity
          end
        end

      when :skipped
        Rails.logger.info("[LessonSession] Skipped create due to active lock for uuid: #{uuid}")
        head :no_content
      end
    end
  rescue ActiveRecord::RecordNotUnique, PG::UniqueViolation => e
    Bugsnag.notify(e)
    head :no_content
  end
end
```

### **Explanation**:
1. We call `with_semaphore_lock` with the `uuid` of the `LessonSession` we’re trying to create. The `ttl` is set to 10 seconds, meaning the lock will expire after 10 seconds if the process hasn’t finished.
2. If the lock is acquired (`:locked`), we proceed with the transaction to create the `LessonSession`.
3. If the lock is already held (`:skipped`), we log the skipped request and return a `no_content` response.

---

## **Testing the Semaphore Lock**

It's essential to test that the lock mechanism works as expected, both when it acquires the lock and when it skips execution because the lock is already held.

Here’s how we write tests for the `SemaphoreLockable` concern using **RSpec**:

### **RSpec Test**

```ruby
require "rails_helper"

class DummyLockController
  include SemaphoreLockable

  attr_reader :results

  def initialize
    @results = []
  end

  def try_lock(key)
    with_semaphore_lock(key, ttl: 2.seconds) do |status|
      results << status
    end
  end
end

RSpec.describe SemaphoreLockable, type: :concern do
  let(:controller) { DummyLockController.new }
  let(:lock_key) { "test-key" }

  before do
    Rails.cache.clear
  end

  it "yields :locked when lock is acquired" do
    controller.try_lock(lock_key)
    expect(controller.results).to eq([:locked])
  end

  it "yields :skipped if lock is already held" do
    controller.try_lock(lock_key)
    controller.try_lock(lock_key) # second call should be skipped

    expect(controller.results).to eq([:locked, :skipped])
  end

  it "releases the lock after block runs" do
    controller.try_lock(lock_key)
    sleep 2.1 # wait for TTL expiration

    controller.try_lock(lock_key)
    expect(controller.results).to eq([:locked, :locked])
  end
end
```

### **Explanation of the Tests**:
1. **`yields :locked when lock is acquired`**: Tests that the lock is acquired on the first attempt.
2. **`yields :skipped if lock is already held`**: Tests that subsequent attempts to acquire the lock while it’s held will be skipped.
3. **`releases the lock after block runs`**: Tests that the lock is properly released after the block finishes and that subsequent attempts can acquire the lock after TTL expiration.

---

## **Conclusion**

Using a **semaphore lock** with **Redis-backed caching** in Rails helps to ensure that your application handles concurrency and race conditions in a safe, predictable manner. By leveraging **`Rails.cache`**, we can ensure that only one process or thread can perform a critical section at a time, preventing issues like duplicate database entries and unique constraint violations.

This approach is highly scalable and works well in distributed environments, making it ideal for high-concurrency applications such as webhooks, background jobs, or any system where idempotency is crucial.

