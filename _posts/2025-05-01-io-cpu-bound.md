---
layout: post
title: "Is Your Endpoint I/O Bound or CPU Bound?"
categories: [Engineering]
tags: [performance, debugging, testing]
description: "How to tell whether a slow endpoint is I/O bound or CPU bound, using system monitors, timing, and cProfile, and why the fix differs for each."
date: "2025-05-01"
---

<audio controls preload="metadata" src="/assets/audio/io-cpu-bound-summary.ogg">
  Your browser does not support the audio element.
</audio>

## Is your endpoint waiting or working?

An endpoint that reads a file and then processes it can be slow for two entirely different reasons: it's waiting on I/O, or it's burning CPU on calculation. The fix for one does nothing for the other, so the first step in optimizing it is figuring out which one you actually have.

### I/O bound looks like this

Speed is limited by disk, network, or some other external resource. CPU utilization stays low to moderate, disk or network activity is high, and performance improves with faster storage or network, or with async I/O that lets the CPU do something else while it waits.

### CPU bound looks like this

Speed is limited by the processor. One or more cores sit near 100%, disk and network activity stay low during the compute phase, and performance improves with a faster CPU, more cores (if the code can use them), or a better algorithm.

Most real endpoints are a mix: I/O bound while reading, CPU bound while calculating. The question is which phase actually dominates total time.

## Diagnosing it

### Start with the system monitor

`top`/`htop` for CPU, `iostat` for disk, `vmstat` for I/O wait time (`%wa`), `nload`/`iftop` for network if the file is remote. High, sustained I/O wait time is a strong signal you're I/O bound before you've looked at any code.

### Time the two phases directly

The fastest way to get a real answer is to time the I/O and CPU portions of the endpoint separately.

```python
import time
import os
import random

def read_file_data(filepath="data_file.txt", lines_to_read=100000, simulate_slow_io_ms=0):
    if not os.path.exists(filepath) or os.path.getsize(filepath) < lines_to_read * 5:
        with open(filepath, "w") as f:
            for i in range(lines_to_read):
                f.write(str(random.random() * 1000) + "\n")

    data = []
    read_start_time = time.perf_counter()
    with open(filepath, "r") as f:
        for i in range(lines_to_read):
            line = f.readline()
            if not line:
                break
            data.append(line.strip())
            if simulate_slow_io_ms > 0:
                time.sleep(simulate_slow_io_ms / 1000.0)
    read_duration = time.perf_counter() - read_start_time
    return data, read_duration

def perform_calculations(data, calculation_intensity=1000):
    calc_start_time = time.perf_counter()
    total_sum = 0
    items_to_process = data[:min(len(data), 50000)]

    for item_str in items_to_process:
        try:
            num = float(item_str)
            for i in range(calculation_intensity):
                num = (num + i * 0.01) * (num - i * 0.01) / (abs(i) + 1)
                num = num % 1000000007
            total_sum = (total_sum + num) % 1000000007
        except ValueError:
            pass
    calc_duration = time.perf_counter() - calc_start_time
    return total_sum, calc_duration

def main_endpoint_logic(io_lines=100000, cpu_intensity=100, slow_io_ms=0, file_path="data.txt"):
    file_data, io_duration = read_file_data(file_path, lines_to_read=io_lines, simulate_slow_io_ms=slow_io_ms)
    result, cpu_duration = (0, 0) if not file_data else perform_calculations(file_data, calculation_intensity=cpu_intensity)

    total_duration = io_duration + cpu_duration
    if total_duration == 0:
        return
    io_percentage = (io_duration / total_duration) * 100
    cpu_percentage = (cpu_duration / total_duration) * 100

    print(f"I/O: {io_duration:.4f}s ({io_percentage:.1f}%)  CPU: {cpu_duration:.4f}s ({cpu_percentage:.1f}%)")
    if io_percentage > 65:
        print("I/O BOUND")
    elif cpu_percentage > 65:
        print("CPU BOUND")
    else:
        print("MIXED")

if __name__ == "__main__":
    # Many lines, a small per-line delay, light calculation -> I/O bound
    main_endpoint_logic(io_lines=200000, cpu_intensity=10, slow_io_ms=0.01, file_path="large_io_file.txt")
    # Few lines, heavy calculation -> CPU bound
    main_endpoint_logic(io_lines=10000, cpu_intensity=1000, slow_io_ms=0, file_path="small_io_file.txt")
```

Running both configurations makes the split obvious: the I/O-heavy run spends most of its time inside `read_file_data`, the CPU-heavy run spends most of its time inside `perform_calculations`.

### Go deeper with cProfile when timing alone isn't enough

```python
import cProfile, pstats

profiler = cProfile.Profile()
profiler.enable()
main_endpoint_logic(io_lines=10000, cpu_intensity=1000)
profiler.disable()

pstats.Stats(profiler).sort_stats('tottime').print_stats(10)
```

`tottime` is time spent in the function itself, `cumtime` includes everything it called. In an I/O-bound run, `read_file_data` and the built-in file operations it calls dominate `tottime`; in a CPU-bound run, `perform_calculations` does.

### Or just log the two durations in production

Wrapping the same two phases in `logging.info` calls with timestamps gives you the same signal in an environment where running a profiler is too invasive, and it's cheap enough to leave on permanently.

## Why it matters

The two bottlenecks call for different fixes, and applying the wrong one wastes effort:

* **I/O bound:** async I/O so the server can handle other requests while waiting, faster storage or network, caching frequently read data, optimizing the query or index if the data comes from a database, connection pooling for network I/O.
* **CPU bound:** a better algorithm first, then code-level optimization (profile down to the line, use a library like NumPy for numeric work), multiprocessing rather than threading if Python's GIL is in the way, offloading to a background worker, caching results if the same computation repeats for the same input.

None of this is a one-shot diagnosis. Start with the system monitor, confirm with timing, and go to cProfile only when the split isn't obvious. Guessing the bottleneck and optimizing for it anyway is how you end up shipping an async rewrite for a problem that was CPU bound all along.
