---
title: "load_async in Rails 8: loading associations concurrently"
date: 2025-11-09
author: "Joey Wang"
description: "Rails 8's load_async runs association queries concurrently instead of one after another, and getting it right means sizing your connection pool correctly."
tags: [rails, ruby, performance, database]
---

Even with `includes`, `preload`, or `eager_load`, association loading before Rails 8 was strictly sequential:

```ruby
# Before Rails 8 - sequential loading
users = User.includes(:posts, :comments, :profile).limit(10)
# Still runs in this order:
# 1. SELECT users
# 2. SELECT posts WHERE user_id IN (...)
# 3. SELECT comments WHERE user_id IN (...)
# 4. SELECT profiles WHERE user_id IN (...)
```

Each query is cheap, but they run one after another, and that adds up when a page needs several independent associations.

## What load_async changes

`load_async` kicks off association queries on Rails' async query executor instead of waiting on each one in turn:

```ruby
users = User.limit(10).to_a

users.load_async(:posts)
users.load_async(:comments)
users.load_async(:profile)

# All three run concurrently; by the time you access the data it's already loaded
```

## Setup

You need Rails 8, a connection pool sized for the extra concurrent connections, and an async query executor configured:

```ruby
# Gemfile
gem 'rails', '~> 8.0'
```

```yaml
# config/database.yml
production:
  adapter: postgresql
  pool: 25  # sized for concurrent async queries, not just request threads
  timeout: 5000
```

```ruby
# config/application.rb
config.active_record.async_query_executor = :global_thread_pool
config.active_record.async_query_executor_concurrency = 5
```

The pool size matters more than people expect: `load_async` doesn't create new connections out of nowhere, it borrows from the same pool your requests already use. Undersize it and you'll trade sequential queries for connection-pool waits, which is not a win.

## A basic example

```ruby
# Controller
def index
  @users = User.active.includes(:posts, :comments).limit(20)
  @users.load_async(:posts, :comments)
end
```

```erb
<% @users.each do |user| %>
  <h3><%= user.name %></h3>
  <p>Posts: <%= user.posts.count %></p>     <!-- already loaded -->
  <p>Comments: <%= user.comments.count %></p> <!-- already loaded -->
<% end %>
```

## Batch processing

`load_async` also pays off across a batch of records that all need the same associations loaded once, up front:

```ruby
class ReportGenerator
  def generate_user_report_async(user_ids)
    users = User.where(id: user_ids).to_a
    users.load_async(:posts, :orders, :preferences, :notifications)

    users.map do |user|
      {
        id: user.id,
        name: user.name,
        total_posts: user.posts.size,
        total_orders: user.orders.size,
        preferences: user.preferences.attributes,
        unread_notifications: user.notifications.unread.count
      }
    end
  end
end
```

## What to watch

**Connection pool exhaustion.** If concurrent async queries outnumber your available connections, some will queue instead of running in parallel, and you've added complexity for no speedup. Size the pool with async load in mind, not just your usual request concurrency.

**Failures should fall back, not crash the request.**

```ruby
def load_user_data_async(user_ids)
  users = User.where(id: user_ids).to_a
  users.load_async(:posts, :comments, :profile)
  users
rescue ActiveRecord::QueryCanceled => e
  Rails.logger.error "Async query failed: #{e.message}"
  User.includes(:posts, :comments, :profile).where(id: user_ids)
end
```

**Only load what you'll actually use.** `load_async` still runs the query; if the view never touches an association, you've spent a connection and gained nothing.

```ruby
# Good: every association gets rendered
@user.load_async(:posts, :comments)

# Wasteful: followers/following are loaded whether or not the view uses them
@user.load_async(:posts, :comments, :followers, :following)
```

It combines cleanly with `includes` for associations you always need, reserving `load_async` for the ones that are common but not universal:

```ruby
@users = User.includes(:profile).where(active: true).limit(20).to_a
@users.load_async(:posts, :comments)
```

## The trade-off

`load_async` is a real win when a request needs several independent associations and your connection pool has headroom. It is not free concurrency: it borrows from the same pool as everything else, and a pool sized for sequential load will just move the wait from "one query at a time" to "queued for a connection." Size the pool, measure before and after on your actual data shape, and add a synchronous fallback for query cancellation. Get those three right and it's a straightforward performance win; skip them and you've added a new failure mode for no benefit.
