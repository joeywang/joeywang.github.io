---
layout: post
title: "Ruby Ractor vs the GVL: When You Get Real Parallelism"
description: "How Ruby's Global VM Lock limits threaded CPU-bound code, and how Ractor bypasses it entirely by trading shared memory for message passing."
date:   2025-05-04 14:41:26 +0100
pin: true
categories: [Engineering]
tags: [ruby, performance]
---

<audio controls preload="metadata" src="/assets/audio/gvl-parallel-summary.ogg">
  Your browser does not support the audio element.
</audio>

### The GVL: one thread at a time

The Global VM Lock (GVL, also called the GIL) ensures only one thread executes Ruby code at any given moment in CRuby. It exists to keep C extension development simple and to protect Ruby's internal data structures without fine-grained locking everywhere.

The cost shows up in CPU-bound multithreaded code. Since only one thread runs Ruby at a time, spreading a computation across threads buys you nothing:

```ruby
require 'benchmark'

def cpu_bound_task
  count = 0
  10_000_000.times do
    count += 1
  end
end

puts "Single thread:"
puts Benchmark.measure { cpu_bound_task }

puts "\nFour threads:"
puts Benchmark.measure {
  threads = []
  4.times do
    threads << Thread.new { cpu_bound_task }
  end
  threads.each(&:join)
}
```

Run it and the four-thread version is not meaningfully faster than the single-threaded one. That's the GVL doing exactly what it's supposed to do.

I/O-bound work is different. A thread waiting on a network call releases the GVL, so other threads can run while it waits:

```ruby
require 'benchmark'
require 'net/http'

def io_bound_task
  Net::HTTP.get(URI('https://www.google.com'))
end

puts "Single thread, four requests:"
puts Benchmark.measure {
  4.times { io_bound_task }
}

puts "\nFour threads, one request each:"
puts Benchmark.measure {
  threads = []
  4.times do
    threads << Thread.new { io_bound_task }
  end
  threads.each(&:join)
}
```

Here the threaded version is genuinely faster, because the threads overlap while waiting on the network instead of competing for the same lock.

The practical rule: use processes, not threads, for CPU-bound work (`Process` gives you real parallelism since each process has its own GVL); use threads for I/O-bound work. JRuby and TruffleRuby don't have a GVL at all, if avoiding it entirely is a requirement.

### Ractor: parallelism by not sharing state

Ruby 3.0 added Ractor to get around the GVL directly. A Ractor is isolated: it doesn't share objects with other Ractors, so it isn't subject to the GVL's single-thread restriction and can run in parallel on separate cores. Ractors talk to each other by passing messages rather than sharing memory, which is what makes the isolation safe.

```ruby
require 'benchmark'

def cpu_bound_task
  count = 0
  10_000_000.times do
    count += 1
  end
end

puts "Single Ractor:"
puts Benchmark.measure { cpu_bound_task }

puts "\nFour Ractors:"
puts Benchmark.measure {
  ractors = []
  4.times do
    ractors << Ractor.new { cpu_bound_task }
  end
  ractors.each(&:take)
}
```

This time the four-Ractor version is actually faster, because the Ractors run in parallel on separate cores instead of taking turns behind the GVL.

Ractors are worth reaching for when the work is CPU-bound and can be split into independent units, and the code can be designed to minimize shared state up front, since there isn't a way to cheat around the isolation. They're also still evolving: treat the API as something that may change across Ruby versions before relying on it for anything long-lived.

### The short version

The GVL is a real constraint on threaded CPU-bound Ruby, not a threading bug to work around: use processes for that case. Ractor is the newer option when you need actual parallel execution inside a single Ruby process, at the cost of designing your code around message passing instead of shared objects.
