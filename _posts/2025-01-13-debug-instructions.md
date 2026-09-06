---
layout: post
title: "Debugging in Ruby, Python, and PHP: byebug, pdb, and Xdebug"
description: "Compares Ruby's byebug, Python's pdb, and PHP's Xdebug side by side, with the core commands and a working example for each language."
date: "2025-01-13"
categories: [Engineering]
tags: [debugging, ruby, python, php]
---

<audio controls preload="metadata" src="/assets/audio/debug-instructions-summary.ogg">
  Your browser does not support the audio element.
</audio>

Every language ships a debugger, but the commands and the feel of using them differ enough that switching stacks mid-week trips people up. Here is what `byebug` in Ruby, `pdb` in Python, and `Xdebug` in PHP actually give you, side by side.

## Ruby Debugging

Ruby's `byebug` (or the newer `debug` gem) is the standard choice. Core commands:

- `next` – moves to the next line in the same context.
- `step` – steps into the next function call.
- `continue` – runs until the next breakpoint.
- `break` – sets a breakpoint at a line.
- `catch` – stops execution when an exception is raised.
- `display` – prints an expression's value automatically at each stop.
- `info` – shows variables, breakpoints, and the current stack frame.
- `list` – shows the surrounding code.
- `trace` – enables call tracing.

```ruby
require 'byebug'

def test_method
  a = 5
  b = 10
  byebug # Set a breakpoint here
  c = a + b
  puts c
end

test_method
```

## Python Debugging

Python's built-in `pdb` covers most needs; `ipdb` adds readline niceties and `debugpy` wires things into VS Code. Core commands:

- `n` (next) – moves to the next line.
- `s` (step) – steps into a function call.
- `c` (continue) – runs until the next breakpoint.
- `b` (break) – sets a breakpoint at a line.
- `tbreak` – a one-time breakpoint.
- `p` – prints an expression's value.
- `l` (list) – shows code context.
- `w` (where) – shows the call stack.
- `q` (quit) – exits the debugger.

```python
import pdb

def test_function():
    a = 5
    b = 10
    pdb.set_trace()  # Set a breakpoint
    c = a + b
    print(c)

test_function()
```

## PHP Debugging

PHP debugging usually means `Xdebug`, with `var_dump()` and `print_r()` covering the quick-and-dirty cases. Xdebug's core operations:

- `step_over` – advances a line without entering function calls.
- `step_into` – steps into function calls.
- `step_out` – steps out of the current function.
- `run` – continues to the next breakpoint.
- `breakpoint_set` – sets a breakpoint at a line.
- `stack_get` – shows the call stack.
- `context_get` – shows local variables.
- `eval` – evaluates an expression.

```php
<?php
debugger_connect();

function testFunction() {
    $a = 5;
    $b = 10;
    xdebug_break(); // Set a breakpoint
    $c = $a + $b;
    echo $c;
}

testFunction();
?>
```

## Comparison

| Feature             | Ruby (`byebug`)      | Python (`pdb`) | PHP (`Xdebug`)                |
|----------------------|-----------------------|----------------|--------------------------------|
| Step execution        | `next`, `step`        | `n`, `s`       | `step_over`, `step_into`       |
| Breakpoints           | `break`               | `b`            | `breakpoint_set`               |
| Exception catching    | `catch`               | `c`            | `context_get`                  |
| Stack trace           | `info`                | `w`            | `stack_get`                    |
| Context info          | `display`             | `p`            | `eval`                         |

All three get the job done. Ruby's command set is the most direct to pick up, Python's `pdb` is close behind and ships with the language, and PHP's Xdebug does the same job but needs an extension installed and configured before it feels as immediate as the other two.
