---
layout: post
title:  "Ractor to solve the problem of GVL"
date:   2025-05-04 14:41:26 +0100
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
