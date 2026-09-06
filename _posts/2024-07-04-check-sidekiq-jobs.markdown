---
layout: post
title: "Inspecting Sidekiq Jobs from the Rails Console"
date:   2024-07-04 14:41:26 +0100
categories: Sidekiq
tags: [sidekiq, ruby, rails, debugging]
description: "Console-ready Ruby snippets to inspect Sidekiq queues, scheduled jobs, retry and dead sets, and currently running workers when the dashboard is not enough."
---

The Sidekiq web UI is fine until you need to answer a specific question: which arguments is that stuck job carrying, or when exactly was this batch enqueued. For that, the console is faster. These are the snippets I paste into a Rails console when a queue misbehaves.

```ruby
def check_queue(queues = [])
  if queues.empty?
    queues = Sidekiq::Queue.all
  else
    queues = queues.map { |queue| Sidekiq::Queue.new(queue) }
  end
  queues.each do |queue|
    queue.each do |job|
      p job
      p job.klass, job.args, job.jid
    end
  end
end

def check_schedule
  Sidekiq::ScheduledSet.new.each do |job|
    puts job.at
  end
end

def check_deadset
  Sidekiq::DeadSet.new.each do |job|
    puts job
  end
end

def check_retryset
  Sidekiq::RetrySet.new.each do |job|
    puts job
  end
end

def check_running_jobs
  workers = Sidekiq::Workers.new
  workers.each do |process_id, thread_id, work|
    p "process_id=#{process_id} thread_id=#{thread_id}"
    p work
    puts "created_at=#{Time.at(work['payload']['created_at'])} enqueued_at=#{Time.at(work['payload']['enqueued_at'])} run_at=#{Time.at(work['run_at'])}"
  end
end
```

A note of caution: these iterate over Redis, so on a queue with hundreds of thousands of jobs, dumping every one to stdout is its own incident. Scope to a named queue when you can.
