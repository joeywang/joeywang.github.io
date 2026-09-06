---
layout: post
title:  "Ruby's GVL vs Ractor: What Actually Runs in Parallel"
description: "Ruby's Global VM Lock serializes threads for CPU-bound work, and Ractor works around it with isolated memory, benchmarked here against threads and processes."
date:   2024-08-03 14:41:26 +0100
pin: true
categories: Ruby
tags: [ruby, performance, debugging]
---

## The GVL: one thread executes Ruby code at a time

The Global VM Lock (GVL), often called the GIL, is the mechanism in CRuby that ensures only one thread executes Ruby code at any given moment. One key, one room: however many threads are waiting, only the one holding the lock can run.

It exists to keep Ruby's C extensions simple and its internal data structures consistent without fine-grained locking everywhere. The cost is that CPU-bound multithreaded code doesn't get faster just by adding threads.

### CPU-bound: threads don't help

```ruby
require 'benchmark'

def cpu_bound_task
  count = 0
  10_000_000.times do
    count += 1
  end
end

puts "Running a CPU-bound task with a single thread:"
puts Benchmark.measure {
  cpu_bound_task
}

puts "\nRunning a CPU-bound task with multiple threads:"
puts Benchmark.measure {
  threads = []
  4.times do
    threads << Thread.new do
      cpu_bound_task
    end
  end
  threads.each(&:join)
}
```

The multi-threaded version isn't meaningfully faster. That's the GVL doing exactly what it's supposed to: only one thread runs Ruby code at a time, regardless of how many you spin up.

### I/O-bound: threads help

```ruby
require 'benchmark'
require 'net/http'

def io_bound_task
  Net::HTTP.get(URI('https://www.google.com'))
end

puts "Running an I/O-bound task with a single thread:"
puts Benchmark.measure {
  io_bound_task
  io_bound_task
  io_bound_task
  io_bound_task
}

puts "\nRunning an I/O-bound task with multiple threads:"
puts Benchmark.measure {
  threads = []
  4.times do
    threads << Thread.new do
      io_bound_task
    end
  end
  threads.each(&:join)
}
```

Here the multi-threaded version wins, because a thread waiting on network I/O releases the GVL, letting another thread run while the first one waits.

### Working around it

For CPU-bound work, use separate processes instead of threads: they don't share a GVL, so they run in parallel across cores. For I/O-bound work, threads are the right tool as-is. If you need true parallelism for CPU-bound Ruby code without forking processes, alternative implementations like JRuby or TruffleRuby don't have a GVL at all.

## Ractor: isolated memory, real parallelism

Ruby 3.0 introduced Ractor as a way to get parallelism without the GVL. Ractors don't share memory with each other, so they aren't subject to the same lock, and they can run on multiple cores simultaneously. Instead of shared state, Ractors communicate by passing messages, which is more explicit than shared-memory threading and rules out a class of race conditions by construction.

```ruby
require 'benchmark'

def cpu_bound_task
  count = 0
  10_000_000.times do
    count += 1
  end
end

puts "Running a CPU-bound task with a single Ractor:"
puts Benchmark.measure {
  cpu_bound_task
}

puts "\nRunning a CPU-bound task with multiple Ractors:"
puts Benchmark.measure {
  ractors = []
  4.times do
    ractors << Ractor.new do
      cpu_bound_task
    end
  end
  ractors.each(&:take)
}
```

The multi-Ractor version is faster here, for the same reason multiple processes are: no shared GVL to serialize execution.

Ractors are worth reaching for when a CPU-bound task breaks cleanly into independent units of work. Because they can't share memory, the code has to be designed around message passing from the start, retrofitting a Ractor onto code built around shared mutable state doesn't work. They're also still marked experimental, and the API has moved between Ruby versions.

## Benchmark: Fibonacci across threads, processes, and Ractors

Same workload, three approaches: `fib(37)` computed six times, timed with `gvl-tracing`.

### Six processes

```ruby
require "gvl-tracing"

def fib(n)
  return n if n <= 1
  fib(n - 1) + fib(n - 2)
end

NR_CORES = 6

def calc
  result = []
  pipes = []
  pids = []

  NR_CORES.times do |i|
    pid = fork do
      fib(37)
    end
    pids << pid
  end

  pids.each do |pid|
    Process.waitpid(pid)
  end
end

GvlTracing.start("fib_process.json") do
  calc
end
```

```bash
time ruby fib_process.rb
ruby fib_process.rb  15.92s user 0.12s system 508% cpu 3.157 total
```

<img width="1355" alt="Screenshot 2024-07-21 at 23 51 12" src="https://gist.github.com/user-attachments/assets/ef6e503e-24d5-421c-8210-583058a2ed5a">

### Six threads

```ruby
require "gvl-tracing"

def fib(n)
  return n if n <= 1
  fib(n - 1) + fib(n - 2)
end

GvlTracing.start("fib_thread.json") do
  Thread.new { sleep(0.05) while true }

  sleep(0.05)

  6.times.map { Thread.new { fib(37) } }.map(&:join)

  sleep(0.05)
end
```

```bash
time ruby fib_thread.rb
ruby fib_thread.rb  12.59s user 0.07s system 95% cpu 13.238 total
```

<img width="1531" alt="Screenshot 2024-07-21 at 23 00 21" src="https://gist.github.com/user-attachments/assets/07c65e80-1937-4c12-9479-02c00c911fe6">

### Six Ractors

```ruby
require 'gvl-tracing'

def fib(n)
  if n < 2
    1
  else
    fib(n - 2) + fib(n - 1)
  end
end

RN = 6
def ractor
  rs = (1..RN).map do |i|
    Ractor.new i do |i|
      [i, fib(37)]
    end
  end

  until rs.empty?
    r, v = Ractor.select(*rs)
    rs.delete r
  end
end

GvlTracing.start("fib_ractor.json") do
  ractor
end
```

```bash
time ruby fib_ractor.rb
fib_ractor.rb:14: warning: Ractor is experimental, and the behavior may change in future versions of Ruby! Also there are many implementation issues.
ruby fib_ractor.rb  23.01s user 0.15s system 515% cpu 4.492 total
```

<img width="1527" alt="Screenshot 2024-07-21 at 22 58 51" src="https://gist.github.com/user-attachments/assets/204b3588-ae9d-43d5-8f9c-05de3a5c3f6e">

Processes finished in 3.16s, threads in 13.24s with no real parallel benefit for CPU-bound work, and Ractors in 4.49s, close to process speed but with more per-message overhead than raw forking.

## Comparison

| Feature       | Thread | Process | Fiber    | Ractor     |
|---------------|--------|---------|----------|------------|
| Parallelism   | Limited| Yes     | No       | Yes        |
| Memory shared | Yes    | No      | Yes      | Limited    |
| Overhead      | Low    | High    | Very low | Medium     |
| Communication | Easy   | Complex | Simple   | Controlled |

## The principle

For CPU-bound work, the GVL limits threads to one core; processes and Ractors both escape it, and this benchmark shows processes still ahead of Ractors on raw speed. Use threads for I/O-bound work, reach for processes or Ractors when you need real parallelism on CPU-bound work, and pick Ractor over `fork` only when message-passing safety is worth more to you than its overhead and its still-experimental status.

---

Reference:
* https://blog.heroku.com/concurrency_is_not_parallelism
* https://en.wikipedia.org/wiki/Fibonacci_sequence
* https://docs.ruby-lang.org/en/3.3/ractor_md.html
* https://ui.perfetto.dev/
* https://github.com/ivoanjo/gvl-tracing
