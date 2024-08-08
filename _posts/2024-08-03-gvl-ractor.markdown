---
layout: post
title:  "Ractor to solve the problem of GVL"
date:   2024-08-03 14:41:26 +0100
categories: Ruby
---
# GIL/GVL
## What is the Global VM Lock (GVL)?
* Also known as the Global Interpreter Lock (GIL)
* A mutex that prevents multiple native threads from executing Ruby code in parallel
* Present in CRuby (the reference implementation of Ruby)

## Purpose of the GVL

* Protects internal data structures from race conditions
* Ensures thread safety in the Ruby interpreter
* Simplifies the implementation of C extensions

## How the GVL works

* Only one thread can execute Ruby code at a time
* Threads take turns acquiring the GVL
* The GVL is released during I/O operations or sleeping

## Impact on Concurrency

* Limits true parallelism in multi-threaded Ruby programs
* CPU-bound tasks cannot run in parallel
* I/O-bound tasks can still benefit from concurrency

## GVL and Performance

* Single-threaded performance is not affected
* Can limit performance in multi-core systems
* Encourages use of process-based parallelism (e.g., forking)

## Working around the GVL

* Use of native extensions for CPU-intensive tasks
* Leveraging I/O concurrency
* Utilizing multiple processes instead of threads
* Exploring alternative Ruby implementations (e.g., JRuby, which doesn't have a GVL)

## Recent Developments

* Gradual improvements in GVL management in newer Ruby versions
* Introduction of Ractor in Ruby 3.0 for parallelism without GVL restrictions
* Ongoing research and development to improve concurrency in Ruby

# Thread

* Definition: Lightweight unit of execution within a process
* Pros: Shared memory, relatively low overhead
* Cons: Limited by GVL, potential race conditions
* Use case: I/O-bound tasks, background jobs


# Process

* Definition: Independent unit of execution with its own memory space
* Pros: True parallelism, isolation
* Cons: Higher memory usage, slower inter-process communication
* Use case: CPU-bound tasks, improving fault tolerance

# Fiber

* Definition: Cooperative, lightweight concurrency primitive
* Pros: Very low overhead, explicit scheduling
* Cons: No parallelism, requires careful management
* Use case: Concurrency within a single thread, implementing coroutines

# Ractor (Ruby 3.0+)

* Definition: Actor-model concurrency with memory isolation
* Pros: True parallelism, reduced risk of race conditions
* Cons: Limited sharing between Ractors, experimental feature
* Use case: Parallel execution of independent tasks

# Comparison Chart
| Feature       | Thread | Process | Fiber | Ractor |
|---------------|--------|---------|-------|--------|
| Parallelism   | Limited| Yes     | No    | Yes    |
| Memory Shared | Yes    | No      | Yes   | Limited|
| Overhead      | Low    | High    | Very Low | Medium |
| Communication | Easy   | Complex | Simple| Controlled |



## Memory Model

* Thread: Shared memory
* Process: Separate memory spaces
* Fiber: Shared memory within a thread
* Ractor: Isolated memory with controlled sharing

# Concurrency vs Parallelism

* Thread: Concurrent, limited parallelism (GVL)
* Process: Parallel
* Fiber: Concurrent, no parallelism
* Ractor: Parallel with isolated state

![GAj2g](https://gist.github.com/user-attachments/assets/08e47342-bd42-4cac-a983-0ee3bc189f6c)
![QjsGt](https://gist.github.com/user-attachments/assets/505a10a4-ff91-46d4-97aa-7f3356365699)


# Use Case Scenarios

* Thread: Web servers, background jobs
* Process: Heavy computations, system commands
* Fiber: Event-driven programming, generators
* Ractor: Parallel data processing, actor-model implementations

# Code Complexity

* Thread: Moderate (need to handle synchronization)
* Process: Simple (but IPC can be complex)
* Fiber: Can be complex (manual scheduling)
* Ractor: Moderate (new concept, restricted object sharing)




# Exmaples: Thread VS Ractor

* Fib(37)
* Run 6 times of the calculation


## Fib Process

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
time ruby fab_process.rb
ruby fab_process.rb  15.92s user 0.12s system 508% cpu 3.157 total
```

<img width="1355" alt="Screenshot 2024-07-21 at 23 51 12" src="https://gist.github.com/user-attachments/assets/ef6e503e-24d5-421c-8210-583058a2ed5a">


## Fib Thread

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
time ruby fab_thread.rb
ruby fab_thread.rb  12.59s user 0.07s system 95% cpu 13.238 total
```
<img width="1531" alt="Screenshot 2024-07-21 at 23 00 21" src="https://gist.github.com/user-attachments/assets/07c65e80-1937-4c12-9479-02c00c911fe6">



## Fab ractor
```ruby
require 'gvl-tracing'

def fib n
  if n < 2
    1
  else
    fib(n-2) + fib(n-1)
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
    #p answer: v
  end
end

GvlTracing.start("fib_ractor.json") do
  ractor
end

```

```bash
time ruby fab_ractor.rb
fab_ractor.rb:14: warning: Ractor is experimental, and the behavior may change in future versions of Ruby! Also there are many implementation issues.
ruby fab_ractor.rb  23.01s user 0.15s system 515% cpu 4.492 total
```
<img width="1527" alt="Screenshot 2024-07-21 at 22 58 51" src="https://gist.github.com/user-attachments/assets/204b3588-ae9d-43d5-8f9c-05de3a5c3f6e">



## Conclusion

* GVL is a crucial part of CRuby's architecture
* Understanding its implications is important for optimizing Ruby applications
* Future Ruby versions may bring more improvements in parallel execution


Reference
---
* https://blog.heroku.com/concurrency_is_not_parallelism
* https://en.wikipedia.org/wiki/Fibonacci_sequence
* https://docs.ruby-lang.org/en/3.3/ractor_md.html
* https://ui.perfetto.dev/
* https://github.com/ivoanjo/gvl-tracing
