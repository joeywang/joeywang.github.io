---
layout: post
title: "Rufus-Scheduler vs Sidekiq-Scheduler for Ruby Jobs"
description: "Comparing rufus-scheduler's in-process polling loop with sidekiq-scheduler's Redis-backed queue to pick the right one for single-process vs distributed apps."
date: 2024-09-07 00:00 +0000
categories: [Engineering]
tags: [ruby, sidekiq, redis, automation]
---
<audio controls preload="metadata" src="/assets/audio/a-deep-dive-into-ruby-job-schedulers-rufus-scheduler-vs-sidekiq-scheduler-summary.ogg">
  Your browser does not support the audio element.
</audio>

Two libraries cover most Ruby job scheduling needs: rufus-scheduler and sidekiq-scheduler. They solve the same problem, run code on a schedule, with opposite architectures, and the difference in architecture is what decides which one fits your app.

## Rufus-Scheduler: The Standalone Scheduler

Rufus-scheduler is a pure Ruby gem that allows you to schedule jobs (blocks of code) for later execution. It's a standalone scheduler that doesn't require any external dependencies.

### Example
```ruby
require 'rufus-scheduler'

scheduler = Rufus::Scheduler.new

scheduler.every '1h' do
  # Do something every hour
end

scheduler.cron '0 22 * * 1-5' do
  # Do something at 10 PM every weekday
end
```

### Key Features:

1. **Versatile Scheduling**: Supports various scheduling methods including at, in, every, and cron.
2. **In-Process Execution**: Jobs are executed within the same process as the scheduler.
3. **No Persistence**: By default, scheduled jobs are not persisted and will be lost if the process terminates.
4. **Lightweight**: Being a pure Ruby solution, it's easy to set up and use in any Ruby application.


Rufus::Scheduler uses a main loop that runs continuously to manage and trigger scheduled jobs. Here's how it works:

1. **Continuous Checking**: The scheduler constantly loops, checking for jobs that are due to run.
2. **Job Triggering**: When a job is due, it's triggered and dispatched to a worker thread for execution.
3. **Worker Threads**: Jobs are executed in separate worker threads, allowing for concurrent execution.
4. **Timeout Handling**: The scheduler monitors job execution time and can terminate jobs that exceed their allowed runtime.



While this approach is simple and works well for many use cases, it has some limitations:

- **Efficiency**: Constantly looping to check for due tasks can be inefficient, especially for infrequent jobs.
- **Scalability**: As the number of jobs increases, the continuous checking can become a bottleneck.
- **Single Process**: Rufus::Scheduler typically runs in a single process, which can limit its use in distributed systems.

## Sidekiq-Scheduler: The Sidekiq Extension

Sidekiq-scheduler is an extension to Sidekiq, a popular background job processing framework for Ruby. It adds scheduling on top of Sidekiq's existing job processing.

### Example

```ruby
# In your Sidekiq initializer
require 'sidekiq-scheduler'

Sidekiq.configure_server do |config|
  config.on(:startup) do
    Sidekiq.schedule = YAML.load_file(File.expand_path("../../config/sidekiq_schedule.yml", __FILE__))
    SidekiqScheduler::Scheduler.instance.reload_schedule!
  end
end

# In config/sidekiq_schedule.yml
my_scheduled_job:
  cron: "0 * * * *" # Runs hourly
  class: MyScheduledJob
```

### Key Features:

1. **Sidekiq Integration**: Builds on Sidekiq's infrastructure for job processing and management.
2. **Redis-Based**: Uses Redis for job persistence, ensuring scheduled jobs survive process restarts.
3. **Web UI**: Provides a web interface for managing scheduled jobs, integrated with Sidekiq's dashboard.
4. **Dynamic Scheduling**: Allows adding or removing schedules at runtime.
5. **YAML Configuration**: Supports defining job schedules in a YAML file.

### Implementation Analysis:

Sidekiq and Sidekiq-scheduler implement a more efficient and scalable approach:

1. **Job Queue in Redis**: Jobs are serialized and stored in Redis lists, allowing for persistence and sharing across multiple processes or servers.
2. **Worker Processes**: Sidekiq runs separate worker processes that pull jobs from Redis, enabling distributed processing.
3. **Efficient Polling**: Sidekiq uses Redis' blocking pop operation (BRPOP) to efficiently wait for new jobs instead of constantly checking.
4. **Scheduled Jobs Storage**: Scheduled jobs are stored in Redis as a sorted set, with the score being the next execution time.
5. **Polling for Due Jobs**: A separate thread periodically checks for due jobs using efficient Redis operations.
6. **Enqueuing Due Jobs**: When a job is due, it's moved from the scheduled set to the regular Sidekiq queue for processing.

The payoff: jobs distribute across machines, survive process restarts, and scale with the number of workers rather than being capped by one process's thread pool.

## Comparison

| Feature           | Rufus-Scheduler                    | Sidekiq-Scheduler                   |
|-------------------|------------------------------------|------------------------------------|
| Execution         | In-process                         | Background workers                 |
| Persistence       | No built-in persistence            | Redis-based persistence            |
| Scalability       | Limited to single process          | Distributed across Sidekiq workers |
| UI                | No built-in UI                     | Integrated with Sidekiq Web UI     |
| Dependencies      | Standalone                         | Requires Sidekiq and Redis         |
| Dynamic Scheduling| Supported                          | Supported                          |
| Cron Syntax       | Supported                          | Supported                          |
| Job Check Method  | Continuous looping                 | Efficient Redis-based polling      |
| Distributed Processing | Not supported                 | Supported                          |

## Which one to use

Rufus::Scheduler is the right call for a small app running in one process, where missing a job occasionally because the process restarted is an acceptable cost, and you don't want the overhead of a full background processing framework. Sidekiq::Scheduler is the right call once you're already running Sidekiq and Redis, or once you need jobs to survive a restart and scale across multiple worker processes. The architecture difference, in-process loop vs. Redis-backed queue, is the whole decision; everything else follows from it.
