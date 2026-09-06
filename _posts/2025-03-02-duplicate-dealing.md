---
layout: post
title: "Avoiding Duplicate Record Errors in Rails Under Concurrency"
description: "Two concurrent requests can both pass an exists? check and race to insert the same row; here is why, and how to write idempotent Rails controllers."
date: "2025-03-02"
categories: [Rails]
tags: [rails, database, testing]
---

<audio controls preload="metadata" src="/assets/audio/duplicate-dealing-summary.ogg">
  Your browser does not support the audio element.
</audio>

Handling duplicate record errors in a Rails app is a common problem the moment concurrent client requests enter the picture. Here's the failure mode, its root cause, and the pattern for writing controller actions that stay idempotent under race conditions instead of raising exceptions.

## The Problem: Duplicate Requests, Duplicate Keys

Imagine you're building a feature where a client creates a `LessonSession` by sending a POST request with a `uuid`. Your controller might look something like this:

```ruby
def create
  if LessonSession.exists?(uuid: permitted_params[:uuid])
    head :no_content
    return
  end

  lesson_session = Current.course.lesson_sessions.new(permitted_params.merge(user: current_user))
  lesson_session.deactivate

  respond_to do |format|
    if lesson_session.save
      lesson_session.create_study_time!
      format.json { head :no_content }
    else
      format.json { render json: lesson_session.errors, status: :unprocessable_entity }
    end
  end
rescue ActiveRecord::RecordNotUnique => e
  Bugsnag.notify(e)
  head :no_content
end
```

This code seems fine at first glance, but it is **not atomic**. Two simultaneous requests with the same `uuid` can both pass the `exists?` check and try to insert a row: only one succeeds, and the other raises a `PG::UniqueViolation`, which Rails wraps as `ActiveRecord::RecordNotUnique`.

### Why Two Exceptions?

You may notice two errors in your logs or error tracker:

1. `PG::UniqueViolation`: This is the low-level PostgreSQL error.
2. `ActiveRecord::RecordNotUnique`: This is the Rails-wrapped version of the above.

```text
ActiveRecord::RecordNotUnique
PG::UniqueViolation: ERROR:  duplicate key value violates unique constraint "index_lesson_sessions_on_uuid"
```

This nesting is intentional. Rails translates low-level DB errors into higher-level, more meaningful exceptions.

---

## Best Practices for Avoiding This Problem

### 1. **Use a Unique Client-Generated Token**

Clients should generate a unique `uuid` for every session creation request. This allows the server to safely detect duplicates.

### 2. **Keep Transactions Small**

Only wrap the minimal code needed to insert or find the record in a transaction. Do not include logic like sending emails, enqueuing jobs, or making API calls inside it.

### 3. **Avoid `exists?` + `create!` Pattern**

This is prone to race conditions. Instead, use atomic operations like `find_or_create_by` or rely on the database’s unique constraint directly.

### 4. **Use Idempotent Create Patterns**

Here is a safer pattern using `find_by` and `save!` inside a transaction:

```ruby
def create
  lesson_session = LessonSession.find_by(uuid: permitted_params[:uuid])
  if lesson_session
    head :no_content
    return
  end

  lesson_session = LessonSession.new(permitted_params.merge(user: current_user, course: Current.course))
  lesson_session.deactivate

  LessonSession.transaction(requires_new: true) do
    lesson_session.save!
    lesson_session.create_study_time!
  end

  head :no_content
rescue ActiveRecord::RecordNotUnique => e
  Bugsnag.notify(e)
  head :no_content
end
```

### 5. **Understand Exception Nesting**

You can inspect exceptions like this:

```ruby
rescue ActiveRecord::RecordNotUnique => e
  puts e.class.name        # => "ActiveRecord::RecordNotUnique"
  puts e.cause.class.name  # => "PG::UniqueViolation"
end
```

This helps if your error tracker shows both errors, which is expected and normal.

---

## Summary

| Best Practice | Reason |
|---------------|--------|
| Use a client-provided UUID | Ensures idempotency |
| Keep transactions small | Reduces lock time and contention |
| Avoid non-atomic patterns | Prevents race conditions |
| Catch `ActiveRecord::RecordNotUnique` | Handles DB-level duplicates gracefully |

---

## The principle

Rails gives you the tools to build safe, concurrent controllers, but it won't write the logic for you. Trust the database's unique constraint over an `exists?` check, keep transactions small, and use a client-provided idempotency token so a retried request is a no-op instead of a second row.

