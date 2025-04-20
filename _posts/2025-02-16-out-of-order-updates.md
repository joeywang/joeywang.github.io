---
layout: post
title: "Best Practices for Handling Out-of-Order Updates"
date: "2025-02-16"
categories: "race conditions" fifo updates
---

# Addressing Out-of-Order Updates in Concurrent Systems

Your question relates to finding better solutions for handling out-of-order updates, which is indeed a critical challenge in distributed systems. Let me explore some additional approaches beyond what was covered in the article.

## Alternative Solution Approaches
Great question — you're touching on another subtle concurrency issue: **out-of-order updates**.

If you have multiple updates hitting an API endpoint or a background job worker, and the **earliest one finishes last**, it can **override more recent data**, leaving the system in an inconsistent or outdated state.

---

## 🧠 Problem Recap:

- Suppose two updates to a `Book` record are triggered in quick succession:
  1. `Book.update(title: "First Draft")`
  2. `Book.update(title: "Final Title")`
- If they are queued or processed asynchronously, **the first one might finish last**, overriding `"Final Title"` with `"First Draft"`.

This is very common in **event-driven architectures**, **webhooks**, **mobile clients with retry logic**, and **distributed workers**.

---

## ✅ Solution Options

### 1. **Use a Redis FIFO queue (First-In-First-Out)**
Yes, this is a good approach.

You can push updates to a Redis list (e.g., `RPUSH book_updates:<book_id>`), and have a **single worker** (or lock-protected consumer) pop and apply them in order (`LPOP`).

**Pros:**
- Guarantees order
- Decouples producer and consumer
- Easy to implement with Sidekiq or custom jobs

**Cons:**
- Requires infrastructure to manage the queue
- Slight delay in processing

---

### 2. **Timestamp-based Conflict Resolution**
Attach a `client_timestamp` or `event_time` to each update payload, and on save:

```ruby
def update_if_newer(params)
  return if params[:client_timestamp] < book.last_synced_at

  book.update!(params.except(:client_timestamp))
  book.update!(last_synced_at: params[:client_timestamp])
end
```

**Pros:**
- Simple logic
- Works well with stateless APIs or mobile apps

**Cons:**
- Requires accurate client clocks or logical timestamps
- Can be fooled by clock skew or retries

---

### 3. **Optimistic Locking (`lock_version`)**
Rails has [built-in optimistic locking](https://guides.rubyonrails.org/active_record_querying.html#optimistic-locking):

```ruby
book.update(title: "Final Title", lock_version: 2)
```

If another update already happened with a newer `lock_version`, the update will **fail** and raise `ActiveRecord::StaleObjectError`.

**Pros:**
- No Redis required
- Native to Rails

**Cons:**
- You need to handle retries
- Best for user-edit conflicts, not async processing

---

### 4. **Single-threaded per-resource processing (Shard + Lock)**
Use a Redis-based lock (like your `SemaphoreLockable`) that locks **per book ID**, to ensure **only one worker** is updating a given book at a time.

Combine with timestamp logic for extra safety.

---

## ✨ TL;DR — Recommendation

For async updates via API or workers:

- ✅ Use Redis FIFO queue per resource **if strict ordering is essential**
- 🧠 Add `client_timestamp` to updates to enforce “latest wins” logic
- 🔒 Use a Redis lock to ensure only one update per resource runs at once

### 5. **Event Sourcing Pattern**
Instead of updating the current state directly, record all changes as immutable events in an event log:

```ruby
# Store events in chronological order
def update_book(book_id, title, timestamp)
  BookEvent.create!(
    book_id: book_id,
    event_type: 'title_updated',
    data: { title: title },
    sequence_number: get_next_sequence(book_id),
    timestamp: timestamp
  )

  # Rebuild current state by replaying events
  rebuild_book_state(book_id)
end
```

**Pros:**
- Complete audit trail of all changes
- Can reconstruct the state at any point in time
- Natural ordering through sequence numbers

**Cons:**
- More complex to implement
- Higher storage requirements
- Potential performance impact when replaying many events

### 6. **Vector Clocks**
Use vector clocks to establish a partial ordering of events without relying on physical timestamps:

```ruby
def update_with_vector_clock(book_id, title, client_vector_clock)
  book = Book.find(book_id)
  server_vector_clock = book.vector_clock

  if vector_clock_is_newer?(client_vector_clock, server_vector_clock)
    book.update!(
      title: title,
      vector_clock: merge_vector_clocks(client_vector_clock, server_vector_clock)
    )
    return true
  end
  return false
end
```

**Pros:**
- Works well in distributed systems without synchronized clocks
- Can detect concurrent updates that need resolution
- More accurate than simple timestamps

**Cons:**
- More complex to implement and understand
- Vector clocks can grow in size with many clients

### 7. **CRDTs (Conflict-Free Replicated Data Types)**
For specific data types, use mathematical structures that automatically resolve conflicts:

```ruby
def update_book_tags(book_id, new_tags)
  book = Book.find(book_id)
  # Use a Set-based CRDT for tags
  book.tags = book.tags.union(new_tags)
  book.save!
end
```

**Pros:**
- Automatic conflict resolution
- Eventually consistent without explicit coordination
- Great for specific use cases (counters, sets, maps)

**Cons:**
- Not applicable to all data types
- More complex for rich text or arbitrary structures

### 8. **Transactional Outbox Pattern**
Store updates in a local transaction with the main record, then process them asynchronously:

```ruby
Book.transaction do
  book.update!(title: "New Title")
  Outbox.create!(
    aggregate_type: 'Book',
    aggregate_id: book.id,
    sequence: generate_sequence(),
    payload: { title: "New Title" }
  )
end

# Separate process reads from outbox in sequence order
```

**Pros:**
- Atomic updates with the main record
- Natural ordering through sequence numbers
- Decoupled processing while maintaining ordering

**Cons:**
- Requires additional table/collection
- Need to implement the outbox processor

## Recommended Comprehensive Solution

For a robust solution to the out-of-order update problem, I recommend combining several approaches:

1. **Use the Transactional Outbox pattern** for reliable event ordering
2. **Implement version vectors or logical timestamps** rather than physical timestamps
3. **Apply domain-specific conflict resolution** rules where possible
4. **Process updates sequentially per resource ID** using sharded queues

This approach gives you:
- Strong ordering guarantees
- Resilience against network issues or retries
- Clean separation between write and processing concerns
- Scalability across many resources

### 9. **Command Sourcing with Idempotent Handlers**

Instead of storing state changes, store the commands that triggered those changes:

```ruby
def process_rename_command(command_id, book_id, new_title)
  # Skip if we've seen this command already
  return if ProcessedCommand.exists?(command_id: command_id)
  
  Book.transaction do
    book = Book.find(book_id)
    book.update!(title: new_title)
    # Mark command as processed to ensure idempotency
    ProcessedCommand.create!(command_id: command_id, processed_at: Time.current)
  end
end
```

**Pros:**
- Ensures each command is processed exactly once
- Can replay commands in order if needed
- Works well with event-driven architectures

**Cons:**
- Requires storing and tracking processed commands
- Must generate unique command IDs

### 10. **Lamport Timestamps**

Use logical clocks that guarantee a consistent ordering across distributed systems:

```ruby
def update_with_lamport_timestamp(book_id, title, client_timestamp)
  book = Book.find(book_id)
  # Increment our logical clock to be greater than both our current clock and client's
  new_timestamp = [book.lamport_timestamp, client_timestamp].max + 1
  
  if client_timestamp > book.last_update_timestamp
    book.update!(
      title: title,
      lamport_timestamp: new_timestamp,
      last_update_timestamp: client_timestamp
    )
    return true
  end
  return false
end
```

**Pros:**
- No need for synchronized physical clocks
- Provides a total ordering of events
- Simpler than vector clocks

**Cons:**
- Doesn't detect concurrent operations like vector clocks
- Requires careful implementation

### 11. **State-Based Delta CRDTs**

Only transmit changes (deltas) rather than full state:

```ruby
def apply_delta(book_id, delta, version)
  book = Book.find(book_id)
  return if version <= book.version
  
  # Apply the specific delta operations
  if delta[:title]
    book.title = delta[:title]
  end
  
  book.version = version
  book.save!
end
```

**Pros:**
- Reduced network traffic
- Can handle partial updates elegantly
- More efficient than full state transfers

**Cons:**
- More complex delta tracking
- Need careful version management

### 12. **Database-Level Row Versioning**

Leverage database capabilities for temporal tables:

```sql
-- PostgreSQL example
CREATE TABLE books_history (LIKE books);

CREATE TRIGGER books_versioning
BEFORE UPDATE ON books
FOR EACH ROW EXECUTE FUNCTION
  (INSERT INTO books_history SELECT *)
```

Then in application code:

```ruby
def update_if_newest(book_id, title, timestamp)
  affected_rows = Book.where(id: book_id)
                     .where("last_modified < ?", timestamp)
                     .update_all(title: title, last_modified: timestamp)
  
  return affected_rows > 0
end
```

**Pros:**
- Leverages database capabilities
- Complete history available
- Atomic operations

**Cons:**
- Database-specific implementation
- Additional storage requirements

## Best Practices

### 1. **Design for Idempotency**

Make all update operations idempotent so they can be safely retried:

```ruby
def idempotent_update(book_id, title, request_id)
  # Check if this exact request was already processed
  return true if ProcessedRequest.exists?(request_id: request_id)
  
  Book.transaction do
    book = Book.find(book_id)
    book.update!(title: title)
    ProcessedRequest.create!(request_id: request_id)
  end
  
  return true
end
```

### 2. **Use Domain-Specific Conflict Resolution Rules**

Define custom merge strategies for different fields:

```ruby
def smart_merge(book_id, updates)
  book = Book.find(book_id)
  
  # Different strategies for different fields
  if updates[:title] && updates[:title_updated_at] > book.title_updated_at
    book.title = updates[:title]
    book.title_updated_at = updates[:title_updated_at]
  end
  
  # For collections like tags, always merge rather than replace
  if updates[:tags]
    book.tags = (book.tags + updates[:tags]).uniq
  end
  
  book.save!
end
```

### 3. **Implement Background Reconciliation**

Periodically verify and repair inconsistencies:

```ruby
def reconcile_book_states
  Book.find_each do |book|
    # Check against authoritative source or compute expected state
    expected_state = compute_expected_state(book)
    
    if book_needs_reconciliation?(book, expected_state)
      apply_reconciliation(book, expected_state)
      log_reconciliation_event(book)
    end
  end
end
```

### 4. **Use Causality Tracking**

Track causal relationships between updates:

```ruby
def update_with_causality(book_id, title, based_on_version)
  book = Book.find(book_id)
  
  if based_on_version != book.version
    # This update was based on outdated information
    return { success: false, conflict: true, current_version: book.version }
  end
  
  book.update!(title: title, version: book.version + 1)
  return { success: true, new_version: book.version }
end
```

### 5. **Implement Circuit Breakers for Offline Operations**

For mobile apps that work offline:

```ruby
class OfflineUpdateManager
  def queue_update(resource_type, resource_id, changes)
    PendingUpdate.create!(
      resource_type: resource_type,
      resource_id: resource_id,
      changes: changes,
      client_timestamp: Time.current,
      status: 'pending'
    )
  end
  
  def sync_when_online
    PendingUpdate.where(status: 'pending').order(:client_timestamp).each do |update|
      result = send_update_to_server(update)
      if result.success?
        update.update!(status: 'completed')
      elsif result.conflict?
        handle_conflict(update, result)
      else
        # Exponential backoff for retries
        update.update!(retry_count: update.retry_count + 1)
      end
    end
  end
end
```

### 6. **Use Change Data Capture (CDC)**

Monitor database changes to ensure consistency across systems:

```ruby
# Using Debezium or similar CDC tool, configure to capture changes
# Then in consumer code:

def process_cdc_event(event)
  if event.operation == 'UPDATE' && event.table == 'books'
    # Propagate change to dependent systems in correct order
    update_search_index(event.after)
    notify_subscribers(event.after)
  end
end
```

### 7. **Implement Gossip Protocols for Eventually Consistent Systems**

For distributed systems that need eventual consistency:

```ruby
def sync_with_peers(local_state, peer_nodes)
  peer_nodes.each do |peer|
    peer_state = fetch_state_from_peer(peer)
    merged_state = merge_states(local_state, peer_state)
    update_local_state(merged_state)
    send_state_to_peer(peer, merged_state)
  end
end
```

## Integration Strategy

For a comprehensive solution, consider this layered approach:

1. **Data Layer**: Use optimistic concurrency control with version fields
2. **API Layer**: Implement idempotent endpoints with request IDs
3. **Processing Layer**: Employ an ordered queue per resource
4. **Consistency Layer**: Run periodic reconciliation jobs
5. **Client Layer**: Design for offline operation with conflict resolution

This multi-layered strategy provides defense in depth against concurrency issues while maintaining system performance and scalability.

Would you like me to provide a more detailed implementation example of any of these approaches in a specific language or framework?
