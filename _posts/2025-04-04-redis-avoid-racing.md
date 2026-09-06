---
title: "Idempotent Rails Requests with a Redis Semaphore Lock"
description: "How to stop duplicate Rails requests from creating the same record twice, using a Redis-backed semaphore lock instead of chasing a race condition."
date: "2025-04-04"
categories: [Rails, Database]
tags: [rails, redis, database, performance]
---

<audio controls preload="metadata" src="/assets/audio/redis-avoid-racing-summary.ogg">
  Your browser does not support the audio element.
</audio>

Race conditions show up whenever two requests can hit the same code path at once and both assume they're first. The common trigger is enforcing uniqueness: creating a resource identified by a client-generated UUID.

## The problem

A `LessonSession` gets created from a `uuid` the client supplies. In a highly concurrent environment, two requests carrying the same `uuid` can arrive close enough together that both pass the existence check before either has saved:

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

Both requests see `persisted?` return false, both try to save, and the second one hits `PG::UniqueViolation`.

## A semaphore lock in front of the critical section

A distributed semaphore lock lets only one request into the critical section at a time; anything arriving while the lock is held gets skipped instead of racing. `Rails.cache`, backed by Redis, gives you this for free through its atomic `write ... unless_exist: true`:

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

`key` identifies what's being locked (the UUID here), `ttl` bounds how long a stuck process can hold it, `namespace` keeps the key space from colliding with unrelated locks.

## Using it in the controller

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

Note the `rescue` at the bottom is still there. The lock closes the window, it doesn't eliminate every possible race (a lock TTL that expires mid-transaction, a process that crashes without releasing the key): the database's unique constraint is still the actual source of truth. The lock exists to make that constraint violation rare instead of routine.

## Testing it

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

## Where this fits

This pattern is for reducing contention on a hot path, webhooks, background jobs, anywhere idempotency matters and duplicate work is expensive or visible to the user. It's not a substitute for the database constraint. Keep both: the lock stops most of the noise, the constraint stops the rest.
