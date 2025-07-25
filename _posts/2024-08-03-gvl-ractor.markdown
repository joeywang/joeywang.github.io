---
layout: post
title:  "Ractor to solve the problem of GVL"
date:   2024-08-03 14:41:26 +0100
pin: true
categories: Ruby
---
### Conquering Concurrency in Ruby: A Deep Dive into the GVL and Ractor

Ruby's ability to handle multiple tasks simultaneously is a cornerstone of its power and flexibility. However, understanding the nuances of how Ruby achieves this is crucial for writing efficient and performant code. This article will take you on a journey through two key concepts in Ruby's concurrency model: the Global VM Lock (GVL) and Ractor. We'll explore what they are, why they exist, and how to leverage them effectively in your Ruby applications.

### The Global VM Lock (GVL): The Gatekeeper of Ruby Threads

The Global VM Lock (GVL), often referred to as the Global Interpreter Lock (GIL), is a mechanism in the CRuby interpreter that ensures only one thread can execute Ruby code at any given moment. Think of it as a single key to a shared room. Even if you have multiple people (threads) wanting to enter the room, only the person with the key can get in and do their work.

#### Why Does the GVL Exist?

The GVL was introduced to simplify the development of Ruby's C extensions and to make Ruby's internals easier to manage. By allowing only one thread to run at a time, the GVL protects against race conditions and ensures that Ruby's internal data structures remain consistent without the need for complex and fine-grained locking mechanisms.

#### The GVL's Impact on Concurrency

While the GVL simplifies Ruby's internals, it has a significant impact on the performance of multithreaded Ruby programs, especially for CPU-bound tasks. Since only one thread can execute Ruby code at a time, you won't see a performance improvement by using multiple threads for tasks that are heavy on CPU calculations.

**CPU-Bound Task Example:**

Let's look at an example of a CPU-bound task. In this code, we'll try to perform a computationally intensive task using multiple threads and see if we get a performance boost.

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

When you run this code, you'll notice that the multi-threaded version is not significantly faster than the single-threaded version. This is the GVL in action, preventing the threads from running in parallel.

**I/O-Bound Task Example:**

However, the GVL is not all bad news. For I/O-bound tasks, where the program spends most of its time waiting for external resources like network requests or file operations, multithreading can still provide a significant performance improvement. When a thread is waiting for I/O, it releases the GVL, allowing another thread to run.

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

In this example, the multi-threaded version will be significantly faster because the threads can run concurrently while waiting for the network requests to complete.

#### Best Practices for Working with the GVL

* **For CPU-bound tasks, use multiple processes instead of threads.** Processes do not share the same GVL, so they can run in parallel on multiple CPU cores. You can use the `Process` module in Ruby to create and manage processes.
* **For I/O-bound tasks, use threads.** Threads are a good choice for I/O-bound tasks because they can run concurrently while waiting for I/O operations to complete.
* **Consider alternative Ruby implementations.** If you need true parallelism for CPU-bound tasks, you can consider using alternative Ruby implementations like JRuby or TruffleRuby, which do not have a GVL.

### Ractor: A New Era of Parallelism in Ruby

To address the limitations of the GVL, Ruby 3.0 introduced Ractor, a new concurrency model that allows for true parallelism. Ractors are isolated actors that do not share state, which means they are not subject to the GVL. This allows them to run in parallel on multiple CPU cores.

#### How Ractors Work

Ractors are similar to threads, but they have a key difference: they do not share memory. This means that each Ractor has its own set of objects, and it cannot directly access the objects of other Ractors. This isolation is what allows Ractors to run in parallel without the need for the GVL.

Ractors communicate with each other by passing messages. This is a more explicit and controlled way of sharing information between concurrent processes, and it helps to prevent race conditions and other concurrency-related bugs.

**Ractor Example:**

Let's see how we can use Ractors to perform a CPU-bound task in parallel.

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

When you run this code, you'll see a significant performance improvement in the multi-Ractor version. This is because the Ractors are running in parallel on multiple CPU cores.

#### Best Practices for Using Ractors

* **Use Ractors for CPU-bound tasks that can be parallelized.** Ractors are a great choice for tasks that are heavy on CPU calculations and can be broken down into smaller, independent units of work.
* **Design your code to minimize shared state.** Since Ractors do not share memory, you'll need to design your code in a way that minimizes the need for shared state. This will make it easier to write correct and efficient Ractor-based programs.
* **Be aware of the experimental nature of Ractors.** Ractors are still a relatively new feature in Ruby, and the API may change in future versions. However, they are a promising new development in Ruby's concurrency story, and they are definitely worth exploring for performance-critical applications.

### Conclusion

The GVL and Ractor are two of the most important concepts to understand when it comes to concurrency and parallelism in Ruby. The GVL, while it has its limitations, is still a useful tool for I/O-bound tasks. Ractor, on the other hand, opens up a new world of possibilities for parallelizing CPU-bound tasks. By understanding how these two mechanisms work, you can write more efficient, performant, and scalable Ruby applications.

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
