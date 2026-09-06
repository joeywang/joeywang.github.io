---
layout: post
title: "Rufus Scheduler: How Its Main Loop Actually Works"
description: "How rufus-scheduler's single-threaded main loop triggers, times out, and runs jobs, and where a timer-based rewrite would scale better."
date: 2024-09-06 00:00 +0000
categories: [Engineering]
tags: [ruby, performance, automation]
---
<audio controls preload="metadata" src="/assets/audio/deep-dive-into-rufus-scheduler-implementation-summary.ogg">
  Your browser does not support the audio element.
</audio>

Rufus-scheduler is a pure Ruby gem for scheduling blocks of code to run later, with no external dependencies. What's less obvious from the README is how it actually decides a job is due: a plain loop that wakes up on a fixed interval and checks. That design has real consequences for how well it scales, worth walking through alongside the core mechanism, how it handles long-running jobs, and where it would need to change to scale further.

## Core Implementation

### Main Scheduling Loop

The heart of Rufus Scheduler is its main loop, implemented in the `start` method:

```ruby
def start
  @started_at = EoTime.now
  @thread = Thread.new do
    while @started_at do
      begin
        unschedule_jobs
        trigger_jobs unless @paused_at
        timeout_jobs
        sleep(@frequency)
      rescue => err
        on_error(nil, err)
      end
    end
    rejoin
  end
  @thread[@thread_key] = true
  @thread[:rufus_scheduler] = self
  @thread[:name] = @opts[:thread_name] || "#{@thread_key}_scheduler"
end
```

This method:
1. Creates a new thread for the scheduler.
2. Continuously loops while the scheduler is running.
3. In each iteration, it:
   - Removes unscheduled jobs
   - Triggers due jobs (if not paused)
   - Checks for timed-out jobs
   - Sleeps for a specified duration

### Job Triggering

The `trigger_jobs` method is responsible for executing due jobs:

```ruby
def trigger_jobs
  now = EoTime.now
  @jobs.each(now) do |job|
    job.trigger(now)
  end
end
```

Each job's `trigger` method adds the job to the scheduler's work queue:

```ruby
def trigger(time)
  return if @scheduler.down?
  @scheduler.work_queue << self
end
```

## Handling Long-Running Jobs

Rufus Scheduler employs several strategies to manage long-running jobs:

1. **Work Threads**: A pool of threads executes jobs concurrently, reducing the risk of blocking.

2. **Job Timeouts**: The `timeout_jobs` method enforces time limits on job execution:

   ```ruby
   def timeout_jobs
     work_threads(:active).each do |t|
       job = t[:rufus_scheduler_job]
       to = t[:rufus_scheduler_timeout]
       ts = t[:rufus_scheduler_time]
       next unless job && to && ts
       to = ts + to unless to.is_a?(EoTime)
       next if to > EoTime.now
       t.raise(Rufus::Scheduler::TimeoutError)
     end
   end
   ```

3. **Non-blocking Jobs**: Jobs can be scheduled with `blocking: false` to allow continued processing of other jobs:

   ```ruby
   scheduler.every '10s', blocking: false do
     # long-running job
   end
   ```

## Limitations and Potential Improvements

While Rufus Scheduler is effective for many use cases, its implementation has some limitations:

1. **Constant Checking**: The continuous loop can be inefficient, especially for infrequent jobs.
2. **Scalability**: As job numbers increase, the constant checking can become a bottleneck.
3. **Single Process**: It typically runs in one process, limiting use in distributed systems.

### Potential Improvements

1. **Timer-based Approach**: Use system timers to wake up the process only when needed:

   ```ruby
   loop do
     next_job_time = calculate_next_job_time()
     timeout = next_job_time - Time.now
     IO.select(nil, nil, nil, timeout)
     run_due_jobs()
   end
   ```

2. **Tiered Scheduling**: Use different checking frequencies for different time scales.

3. **Sorted Job List**: Keep jobs sorted by next run time to check only the most imminent ones.

4. **Dynamic Sleep Duration**: Calculate sleep time based on the next due job:

   ```ruby
   def improved_start
     @thread = Thread.new do
       while @started_at
         next_job_time = @jobs.next_job_time
         now = Time.now
         if next_job_time > now
           sleep_duration = [next_job_time - now, MAX_SLEEP].min
           sleep(sleep_duration)
         else
           trigger_due_jobs(now)
           timeout_jobs
         end
       end
     end
   end
   ```

5. **System Integration**: For long-running applications, consider integrating with system-level schedulers like systemd timers or cron.

## Where this breaks down

The main loop with worker threads is fine for a handful of jobs on a fixed cadence. It stops being fine once you have enough jobs, or infrequent enough jobs, that constant polling wastes cycles waiting for nothing to be due. A sorted job list and a dynamic sleep duration, sleeping until the next actual due time instead of a fixed interval, fixes that without changing the public API. It's a useful design to have read once, since the same tradeoff (poll on a fixed interval vs. wake on the next known event) shows up in most schedulers you'll build or evaluate.
