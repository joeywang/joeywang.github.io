---
layout: post
title: "Debugging Exceptions: Break on Throw, Not Catch-All"
date: 2025-04-26
tags: [debugging, testing, productivity]
categories: [Engineering]
description: "Catch-all exception handlers hide the real bug. Debuggers that pause on every thrown exception, caught or not, find it faster than logging ever will."
---
<audio controls preload="metadata" src="/assets/audio/catch-exceptions-catch-summary.ogg">
  Your browser does not support the audio element.
</audio>

## What catch-all exceptions actually cost you

`catch (Exception e)` in C#, `catch (Throwable t)` in Java, `except Exception as e` in Python: all convenient, all guarantee the program won't crash on an unhandled exception. That guarantee is also the problem.

* **It masks the real error.** A `NullReferenceException` or `OutOfMemoryError` gets caught by a generic handler and the program limps on in an inconsistent state instead of failing where the bug actually is.
* **It throws away context.** A generic catch loses the specific exception type and the details that would tell you whether this was a missing file, a network timeout, or bad input.
* **An empty `catch` block is the worst version of this.** The exception is caught, discarded, and the program continues as if nothing happened. Debugging that later, if you even notice, is close to impossible.
* **Not every exception deserves the same treatment.** A missing config file and an out-of-bounds array access are different categories of problem; a catch-all treats them identically.

## Pausing on every exception

Most debuggers can break the moment an exception is thrown, whether or not it's inside a `try/catch`, not just when it goes unhandled. That single feature does more to find these bugs than any amount of extra logging.

**Visual Studio (C#/.NET):** `Debug > Windows > Exception Settings`, check the category or specific exception you want. Right-click an exception to restrict it to "unhandled in user code" if you only want the ones your code doesn't catch.

**Chrome DevTools (JavaScript):** Sources panel, the "pause on exceptions" icon. Enable "pause on caught exceptions" to catch everything, not just uncaught ones.

**JetBrains IDEs (IntelliJ, PyCharm):** `Run > View Breakpoints`, add a Java/Python Exception Breakpoint, either a specific class or "Any Exception."

With this on, you see the exact line where the exception originates, even inside a `try/catch`, and can inspect the call stack and variable state at that instant instead of reconstructing it from a log line after the fact.

## Handling exceptions once you've found them

1. **Catch specific types**, not `Exception`. Only catch what you can genuinely handle or recover from; let the rest propagate.
2. **Never leave a `catch` block empty.** Log it, show the user something meaningful, retry or fall back if that's viable, or rethrow (wrapped in a more specific exception if that adds context).
3. **Log the full stack trace and the relevant input**, once, at the point where you either handle the exception or decide to rethrow it. Logging the same exception at every layer just pollutes the log.
4. **Use `finally`** (or `using`/try-with-resources) for cleanup that has to run regardless of outcome.
5. **Don't use exceptions for normal control flow.** Invalid user input is a validation problem, not an exception.
6. **Custom exceptions should carry meaning**, not just exist for their own sake, derived from a standard base class so they compose with the rest of the exception hierarchy.

The debugger's pause-on-throw is the tool that turns "why did this fail" from a guessing game into a five-second answer. Catch-all handlers are the thing that took that answer away in the first place.
