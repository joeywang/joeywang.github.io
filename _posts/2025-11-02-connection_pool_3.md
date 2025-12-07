---
title: "Rails 8.1.1 + Ruby 3.4 + connection_pool 3.x: RedisCacheStore boot crash and a safe monkey-patch"
layout: post
date: 2025-11-02
categories: [rails, ruby, debugging, caching]
---

# Rails 8.1.1 + Ruby 3.4 + connection_pool 3.x: RedisCacheStore boot crash and a safe monkey-patch

## Summary

Upgrading to **Ruby 3.4** and pulling in **connection_pool 3.x** can break a **Rails 8.1.1** app at boot with:

```
ArgumentError: wrong number of arguments (given 1, expected 0)
… connection_pool.rb:48 in `initialize`
… redis_cache_store.rb:163 in `new`
Tasks: TOP => webpacker:compile => environment
```

This happens **before initializers run**, so a normal `config/initializers/*.rb` patch is too late.
We fixed it by **monkey-patching RedisCacheStore early** to pass pool options as proper keyword args and **bypassing Rails’ buggy `initialize`**.

---

## The symptom

During boot (including `webpacker:compile` in Docker), Rails tries to create the cache store and aborts:

* stack trace points to `ActiveSupport::Cache::RedisCacheStore#initialize`
* failure occurs inside `ConnectionPool.new(...)`

This blocks any task that loads the Rails environment.

---

## Root cause

### 1) Ruby 3.x keyword arguments are strict

Since Ruby 3.0, a trailing Hash is no longer automatically treated as keyword arguments. You must explicitly splat keywords with `**`. This tightening is continued in Ruby 3.4. ([Stack Overflow][1])

### 2) connection_pool 3.x expects keywords

`connection_pool` 3.x defines its initializer to accept keyword arguments only (e.g., `ConnectionPool.new(size:, timeout:)`). With Ruby 3.4, calling it with a positional Hash will not auto-convert into keywords.

### 3) Rails 8.1.1 passes a positional Hash

Rails 8.1.1’s `RedisCacheStore` wraps a pool like:

```ruby
ConnectionPool.new(pool_options) { … }
```

where `pool_options` is a Hash derived from your `pool:` config. Rails’ Redis cache store supports pooling this way. ([Ruby on Rails API][2])

Under Ruby 3.4 + connection_pool 3.x:

* `ConnectionPool.new(pool_options)` = positional argument
* initializer expects **zero positional args**
* Ruby raises:

```
ArgumentError: wrong number of arguments (given 1, expected 0)
```

---

## Why a normal initializer patch fails

Rails constructs the cache store during **bootstrap (`initialize_cache`)**, which runs **before** `config/initializers` is loaded. So:

* your initializer never executes
* boot dies first

The patch must be required from `config/application.rb` (or earlier).

---

## Fix options (for context)

1. **Pin connection_pool to 2.4.x**
   Simple, safe, but defers moving forward.

2. **Disable pooling for Redis cache (`pool: false`)**
   Works if you don’t need pooling in that environment.

3. **Monkey-patch RedisCacheStore (what we did)**
   Keeps pooling and avoids a gem downgrade.

---

## Final working monkey-patch (early-load)

### File: `lib/patches/redis_cache_store_connection_pool.rb`

```ruby
# lib/patches/redis_cache_store_connection_pool.rb
require "active_support/cache/redis_cache_store"

# Patch Rails 8.1.1 to work with connection_pool 3.x + Ruby 3.4.
#
# Rails 8.1.1 calls:
#   ConnectionPool.new(pool_options) { ... }   # positional hash
# which breaks on Ruby 3.4.
#
# We change it to:
#   ConnectionPool.new(**pool_options) { ... } # keyword args
#
# IMPORTANT: we must NOT call super() to RedisCacheStore#initialize,
# because that would re-run the buggy code. Instead we call the parent
# ActiveSupport::Cache::Store initializer directly.

module RedisCacheStoreConnectionPoolPatch
  def initialize(error_handler: nil, **redis_options)
    error_handler ||= self.class::DEFAULT_ERROR_HANDLER

    universal_options =
      redis_options.extract!(*ActiveSupport::Cache::UNIVERSAL_OPTIONS)

    redis = redis_options[:redis]

    already_pool =
      redis.instance_of?(::ConnectionPool) ||
      (redis.respond_to?(:wrapped_pool) &&
        redis.wrapped_pool.instance_of?(::ConnectionPool))

    if !already_pool &&
       (pool_options = self.class.send(:retrieve_pool_options, redis_options))
      # ✅ FIX: pass pool_options as keywords
      @redis = ::ConnectionPool.new(**pool_options) do
        self.class.build_redis(**redis_options)
      end
    else
      @redis = self.class.build_redis(**redis_options)
    end

    @error_handler = error_handler

    # 🚫 Don't call super(), it hits buggy Rails 8.1.1 initialize.
    ActiveSupport::Cache::Store.instance_method(:initialize)
      .bind(self)
      .call(universal_options)
  end
end

ActiveSupport::Cache::RedisCacheStore.prepend(RedisCacheStoreConnectionPoolPatch)
```

### Load it early in `config/application.rb`

At the very top, before `rails/all`:

```ruby
# config/application.rb
require_relative "boot"

# Must be loaded before Rails bootstraps cache
require_relative "../lib/patches/redis_cache_store_connection_pool"

require "rails/all"
# ...
```

---

## How this patch works

* It **copies Rails 8.1.1’s initialize logic**

* Changes only the pool creation line:

  **from**

  ```ruby
  ConnectionPool.new(pool_options)
  ```

  **to**

  ```ruby
  ConnectionPool.new(**pool_options)
  ```

* It then **avoids calling Rails’ original initialize** (which would crash again) by directly invoking the parent cache store initializer.

This preserves caching behavior, pooling, errors handling, and universal options.

---

## Removal plan

Delete:

1. `lib/patches/redis_cache_store_connection_pool.rb`
2. the corresponding `require_relative` line in `config/application.rb`

once Rails ships a version where `RedisCacheStore` uses keyword splat for pool options (i.e., `ConnectionPool.new(**pool_options)`).

---

## Quick verification

After applying the patch:

```bash
bundle exec rails runner 'p Rails.cache.class'
bundle exec rails runner 'Rails.cache.write("x", 1); p Rails.cache.read("x")'
```

and confirm Docker build step:

```bash
bin/rails webpacker:compile
```

boots cleanly.

---

## Takeaways

* Ruby keyword-arg strictness + gem API tightening can surface as “wrong number of arguments” deep in framework boot.
* When a failure happens during Rails bootstrap, patches must load **before initializers**.
* `prepend` is great for targeted overrides **as long as you don’t re-call the buggy method**.

---

If you want, I can help turn this into a PR template note (with links to the upstream Rails fix once it lands) so it’s easy to sunset.

[1]: https://stackoverflow.com/questions/75617085/ruby-3-0-wrong-number-of-arguments-given-3-expected-1-2?utm_source=chatgpt.com "Ruby 3.0 - wrong number of arguments (given 3, expected 1..2)"
[2]: https://api.rubyonrails.org/classes/ActiveSupport/Cache/RedisCacheStore.html?utm_source=chatgpt.com "ActiveSupport::Cache::RedisCacheStore - Ruby on Rails"
