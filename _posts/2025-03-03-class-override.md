---
layout: post
title: "Monkey-Patching in PHP vs Ruby: Why One Is an Anti-Pattern"
description: "Runtime method overrides work very differently in PHP and Ruby: one has no rollback mechanism, the other builds aliasing and scoping in from the start."
date: 2025-03-03 14:41:26 +0100
categories: [Engineering]
tags: [php, ruby, testing]
---

<audio controls preload="metadata" src="/assets/audio/class-override-summary.ogg">
  Your browser does not support the audio element.
</audio>

Monkey-patching, also called runtime method override or class reopening, lets you modify an existing class or module after it's already defined. In Ruby it's a supported, manageable feature. In PHP it's closer to an anti-pattern, mostly because the language gives you no way to undo it cleanly.

---

## Thinking Critically about Overriding Class Methods

Before getting into language-specific mechanics, it's worth asking why developers override class methods at runtime in the first place, and when it slips from a handy trick into an anti-pattern.

1. **Breaking Encapsulation:** By reaching inside and altering a class’s behavior post-definition, you violate its encapsulation. A class’s internal logic was designed to process inputs in a certain way; overriding methods circumvents that intent, making behavior unpredictable.

2. **Obscuring Intent:** Tests or patches that redefine methods inline can obscure what a class is supposed to do. Future maintainers may not realize that behavior has been monkey-patched, leading to debugging nightmares.

3. **Entrenching Technical Debt:** Quick fixes via runtime overrides often remain long after initial tests pass. Without explicit rollback mechanisms, these hacks can sneak into production, leaving legacy code that is difficult to trace or refactor.

4. **Encouraging Poor Design:** Reliance on runtime overrides can discourage proper design patterns (like dependency injection or interface-based architecture), since it offers a shortcut past designing flexible, testable classes.

5. **Test Isolation Issues:** As a special case of global state, method-level patches can leak between tests, making suites order-dependent and brittle: one of the hallmarks of an anti-pattern.

## 1. PHP: The Hidden Cost of Runtime Overrides

### 1.1 Why It Feels Like a Shortcut

Developers sometimes reach for extensions like **runkit** or **uopz** to override methods directly on a loaded class:

```php
// Using runkit to redefine a method
runkit_method_redefine(
    'User',
    'greet',
    '',
    'return "Hello from mock!";'
);
```

At first glance, this seems to allow precise control over internal behavior without changing production code. But it introduces significant drawbacks.

### 1.2 Fragile Tests and Global State

1. **Persistent overrides per request**: Once runkit redefines `User::greet()`, the override persists for the remainder of the PHP process. Subsequent tests or code will see the mock unless the process is restarted.
2. **Order-dependent failures**: Tests that assume a fresh environment can pass or fail unpredictably based on which earlier test ran the override.

### 1.3 No Built-in Rollback Mechanism

PHP’s core engine compiles classes and loads them into memory without tracking original method definitions. Extensions like runkit do not store the original body by default, so there is no straightforward `runkit_method_restore()` counterpart. Any rollback logic must manually alias and remove methods:

```php
// Manual aliasing workaround
class User {
    public function greet() { return "Hello!"; }
}

// Save original
User::class_alias('User', 'OriginalUser');

// Override
runkit_method_redefine('User', 'greet', '', 'return "Mocked!";');

// Restore by reloading class definitions (requires separate process)
```

This inevitably leads to process isolation via `@runInSeparateProcess`, impairing test suite performance.

### 1.4 Better Alternatives in PHP

* **Dependency Injection**: Define interfaces and inject collaborators via constructors.
* **PHPUnit Mocks**: Use `$this->getMockBuilder(User::class)` to create proxy objects that override methods only on the mock instance.
* **Mockery**: A popular, expressive mocking library that lets you create mocks fluent-style. For example:

  ```php
  use Mockery;

  class UserTest extends PHPUnit\Framework\TestCase
  {
      public function tearDown(): void
      {
          Mockery::close();
      }

      public function testGreetWithMockery()
      {
          $mockUser = Mockery::mock(User::class)
              ->shouldReceive('greet')
              ->once()
              ->andReturn('Hello from Mockery!')
              ->getMock();

          $result = $mockUser->greet();
          $this->assertEquals('Hello from Mockery!', $result);
      }
  }
  ```

---

## 2. Ruby: Language-Level Support for Safe Patching

### 2.1 Open Classes and Dynamic Method Tables

In Ruby, classes are always open. Redefining a method simply updates the class’s method table:

```ruby
class User
  def greet; "Hello!"; end
end

# Later...
class User
  def greet; "Hi there!"; end
end
# No compile-time locks; calls to User#greet now return "Hi there!"
```

### 2.2 Easy Aliasing and Rollback

Ruby’s `alias_method` provides a built-in way to preserve originals:

```ruby
class User
  alias_method :original_greet, :greet

  def greet
    "Test greeting"
  end
end

# After tests
class User
  alias_method :greet, :original_greet
  remove_method :original_greet
end
```

Aliases live in the method table, making restoration straightforward.

### 2.3 Refinements: Scoped Monkey-Patching

Refinements, introduced in Ruby 2.0, let you apply overrides lexically:

```ruby
module TestPatches
  refine User do
    def greet; "Patched!" end
  end
end

using TestPatches
user.greet   # => "Patched!"
# Outside this file, User#greet remains unchanged
```

Refinements avoid global side-effects automatically.

### 2.4 Test Framework Integration

RSpec and other frameworks stub methods at the instance or proxy level and auto-cleanup:

```ruby
RSpec.describe User do
  it "uses the stub" do
    user = User.new
    allow(user).to receive(:greet).and_return("Stubbed!")
    expect(user.greet).to eq("Stubbed!")
  end
end
```

Minitest provides a simple `stub` helper to override methods within a block scope:

```ruby
require 'minitest/autorun'

describe User do
  it "uses stub in Minitest" do
    user = User.new
    user.stub :greet, 'Hello from stub!' do
      assert_equal 'Hello from stub!', user.greet
    end
    # Outside the block, User#greet returns original value
  end
end
```

---

## 3. Deep Dive: Comparing Workflows

| Aspect             | PHP (runkit/uopz)                              | Ruby (core + RSpec)                            |
| ------------------ | ---------------------------------------------- | ---------------------------------------------- |
| Override Mechanism | C-extension, modifies opcode or AST at runtime | Core VM updates method table at runtime        |
| Rollback           | Manual or process isolation (@runSeparate)     | `alias_method` or automatic via RSpec cleanup  |
| Scope of Patch     | Global for process                             | Global, lexical (Refinements), or per-instance |
| Test Integration   | Limited; can use process isolation             | Built-in via RSpec, Minitest, Mocha, etc.      |

---

## The difference that matters

Both languages support runtime method overrides. Ruby's open classes, `alias_method`, refinements, and test-framework cleanup make monkey-patching a manageable tool with a clear way back. PHP's lack of a built-in rollback means the same trick, done with runkit or uopz, turns into a brittle hack that leans on process isolation to stay safe. In either language, dependency injection and object-level test doubles are the better default; reach for a runtime override only when there's genuinely no other way in.
