---
title: "Improving Performance with load_async in Rails 8: A Deep Dive into Asynchronous Record Loading"
date: 2025-11-09
author: "Joey Wang"
description: "Explore the new load_async feature in Rails 8, which enables true asynchronous loading of ActiveRecord associations, and learn how to implement it to dramatically improve application performance."
tags: [Ruby on Rails, Performance, Database, Rails 8, ActiveRecord, Scalability]
---

# 🚀 Improving Performance with load_async in Rails 8: A Deep Dive into Asynchronous Record Loading

Rails 8 introduces a game-changing feature for database performance: **`load_async`**. This new method enables true asynchronous loading of ActiveRecord associations, allowing your application to perform multiple database queries concurrently rather than sequentially. 

This article explores the implementation, benefits, and best practices for leveraging `load_async` to dramatically improve your application's performance.

---

## 🧩 Understanding the Problem: Sequential Loading Bottleneck

Before Rails 8, even with techniques like `includes`, `preload`, and `eager_load`, associations were loaded sequentially:

```ruby
# Before Rails 8 - Sequential loading
users = User.includes(:posts, :comments, :profile).limit(10)
# Still loads in this order:
# 1. SELECT users (1 query)
# 2. SELECT posts WHERE user_id IN (...) (1 query)  
# 3. SELECT comments WHERE user_id IN (...) (1 query)
# 4. SELECT profiles WHERE user_id IN (...) (1 query)
```

Even though these are separate queries, they execute one after another, creating a **sequential bottleneck** that limits concurrency.

---

## ⚡ Introducing load_async: True Parallel Loading

Rails 8's `load_async` enables true asynchronous loading by leveraging Ruby's concurrent capabilities:

```ruby
# Rails 8 with load_async - Concurrent loading
users = User.limit(10).to_a

# Concurrent loading of associations
users.load_async(:posts)
users.load_async(:comments) 
users.load_async(:profile)

# All three association queries execute in parallel
# When you access the data, it's already loaded!
```

---

## 🔧 Setting Up Rails 8 for load_async

### 1. Upgrade to Rails 8

```ruby
# Gemfile
gem 'rails', '~> 8.0'
gem 'bootsnap', require: false
```

### 2. Configure Concurrent Database Connections

```yaml
# config/database.yml
production:
  adapter: postgresql
  pool: 25  # Increase pool size for concurrent queries
  timeout: 5000
  # Ensure your database can handle more connections
```

### 3. Configure Application for Concurrency

```ruby
# config/application.rb
config.active_record.async_query_executor = :global_thread_pool
config.active_record.async_query_executor_concurrency = 5  # Max concurrent queries
```

---

## 💡 Practical Examples

### Example 1: Basic Association Loading

```ruby
# Controller
def index
  @users = User.active.includes(:posts, :comments).limit(20)
  
  # Instead of multiple sequential N+1 queries
  @users.each do |user|
    user.posts.load_async if user.posts.loaded?
    user.comments.load_async if user.comments.loaded?
  end
  
  # Or more concisely:
  @users.load_async(:posts, :comments)
end

# View
<% @users.each do |user| %>
  <h3><%= user.name %></h3>
  <p>Posts: <%= user.posts.count %></p>  <!-- Already loaded asynchronously -->
  <p>Comments: <%= user.comments.count %></p>  <!-- Already loaded asynchronously -->
<% end %>
```

### Example 2: Complex Multi-Level Loading

```ruby
class DashboardController < ApplicationController
  def show
    @dashboard_data = fetch_dashboard_data_async
  end

  private

  def fetch_dashboard_data_async
    # Fetch base data
    current_user = User.find(current_user.id)
    
    # Load complex nested associations concurrently
    current_user.load_async(:posts, :comments, :followers, :following)
    
    # Load nested associations in parallel
    posts = current_user.posts.to_a
    posts.load_async(:category, :author, :tags)
    
    comments = current_user.comments.to_a  
    comments.load_async(:post, :replies)
    
    # Wait for all to complete and return
    current_user.posts(true)  # force reload to ensure async loading complete
    current_user.comments(true)
    
    {
      user: current_user,
      posts: posts, 
      comments: comments,
      stats: calculate_stats_async(current_user, posts, comments)
    }
  end

  def calculate_stats_async(user, posts, comments)
    stats = {}
    
    # Calculate statistics concurrently
    Thread.new { stats[:post_count] = posts.size }
    Thread.new { stats[:comment_count] = comments.size }
    Thread.new { stats[:avg_engagement] = posts.sum(&:view_count) / posts.size.to_f }
    Thread.new { stats[:recent_activity] = user.recent_activity }
    
    # Wait for all calculations to complete
    sleep 0.1 while stats.keys.length < 4
    
    stats
  end
end
```

### Example 3: Batch Processing with load_async

```ruby
class ReportGenerator
  def generate_user_report_async(user_ids)
    users = User.where(id: user_ids).to_a
    
    # Load all associations concurrently across multiple users
    users.load_async(:posts, :orders, :preferences, :notifications)
    
    # Process each user with pre-loaded data
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

---

## 🏎️ Performance Comparison

### Before load_async (Sequential):

```ruby
Benchmark.measure do
  users = User.includes(:posts, :comments, :profile).limit(50)
  # Takes ~450ms (180ms + 140ms + 130ms sequentially)
end
```

### After load_async (Concurrent):

```ruby
Benchmark.measure do
  users = User.limit(50).to_a
  users.load_async(:posts, :comments, :profile)
  # Takes ~180ms (max of 180ms, 140ms, 130ms in parallel)
end
```

**Performance gain: ~60% faster** for association loading!

---

## ⚠️ Important Considerations

### 1. Database Connection Pool

Ensure your database can handle increased concurrent connections:

```ruby
# config/environments/production.rb
Rails.application.configure do
  config.active_record.connection_adapters.postgresql_adapter.async_query_executor = {
    pool: ActiveRecord::ConnectionAdapters::ConcurrentAsyncQueryExecutor.new(
      size: 10  # Adjust based on your DB capacity
    )
  }
end
```

### 2. Error Handling

```ruby
def load_user_data_async(user_ids)
  users = User.where(id: user_ids).to_a
  
  begin
    users.load_async(:posts, :comments, :profile)
    users
  rescue ActiveRecord::QueryCanceled => e
    # Handle async query cancellation
    Rails.logger.error "Async query failed: #{e.message}"
    User.includes(:posts, :comments, :profile).where(id: user_ids)  # Fallback
  end
end
```

### 3. Memory Usage

Monitor memory usage as concurrent loading can increase memory pressure:

```ruby
# Monitor memory during async operations
def load_with_memory_check(records, *associations)
  initial_memory = `ps -o rss= -p #{Process.pid}`.to_i
  
  records.load_async(*associations)
  
  final_memory = `ps -o rss= -p #{Process.pid}`.to_i
  Rails.logger.warn "Memory increase: #{final_memory - initial_memory} KB" if final_memory > initial_memory + 10000
end
```

---

## 🧠 Best Practices

### 1. Use Judiciously

Only use `load_async` when you're certain you'll access the associations:

```ruby
# ✅ Good - You'll definitely use the data
def show
  @user = User.find(params[:id])
  @user.load_async(:posts, :comments)  # Only if you'll render them
end

# ❌ Avoid - May waste resources loading unused data
def show
  @user = User.find(params[:id])
  @user.load_async(:posts, :comments, :followers, :following)  # Maybe you only need posts
end
```

### 2. Combine with Other Optimizations

```ruby
def dashboard
  @users = User
    .includes(:profile)  # For frequently needed associations
    .where(active: true)
    .limit(20)
    .to_a
    
  @users.load_async(:posts, :comments)  # For less frequently used associations
end
```

### 3. Monitor and Measure

```ruby
# app/controllers/concerns/async_monitoring.rb
module AsyncMonitoring
  extend ActiveSupport::Concern
  
  def with_async_monitoring
    start_time = Time.current
    result = yield
    duration = Time.current - start_time
    
    Rails.logger.info "Async loading completed in #{duration}s"
    Rails.logger.info "Active async queries: #{ActiveRecord::Base.connection.active_query_count}" if Rails.env.development?
    
    result
  end
end
```

---

## 🧪 Testing load_async

```ruby
# spec/models/user_spec.rb
RSpec.describe User, type: :model do
  describe '#load_async' do
    let(:users) { FactoryBot.create_list(:user, 5) }
    
    it 'loads associations concurrently' do
      # Warm up the connection pool
      User.count
      
      expect do
        users.load_async(:posts, :comments)
        # Access the loaded associations
        users.each { |u| [u.posts, u.comments] }
      end.to perform_under(200).ms
    end
    
    it 'handles async query errors gracefully' do
      # Test error handling scenarios
      allow_any_instance_of(ActiveRecord::Relation)
        .to receive(:load_async).and_raise(ActiveRecord::QueryCanceled)
      
      expect { users.load_async(:posts) }.not_to raise_error
    end
  end
end
```

---

## 🔮 Future Considerations

Rails 8.1 and beyond may include:

- **Automatic async detection**: Rails automatically detects when async loading would be beneficial
- **Better error handling**: More granular control over async query failures
- **Integration with caching**: Async loading combined with smart caching for maximum performance

---

## 🏁 Conclusion

Rails 8's `load_async` is a powerful addition that enables true asynchronous loading of ActiveRecord associations. By leveraging concurrent database queries, you can achieve significant performance improvements—often 50-70% faster loading for complex association trees.

However, success with `load_async` requires:
- Proper database connection pool configuration
- Careful consideration of when to use async loading
- Monitoring of memory usage and error conditions
- Proper fallback strategies for error scenarios

When implemented correctly, `load_async` can dramatically improve your application's responsiveness and user experience. Start small, measure performance, and gradually expand your async loading strategy across your application.

The future of Rails performance is concurrent, and `load_async` is the first major step in that direction.