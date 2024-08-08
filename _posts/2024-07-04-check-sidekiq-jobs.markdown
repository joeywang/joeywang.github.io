---
layout: post
title:  "Ruby code to check sidekiq jobs"
date:   2024-07-04 14:41:26 +0100
categories: Sidekiq
tags: [sidekiq, jobs, ruby]
---
```ruby
def check_queue(queues=[])
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
