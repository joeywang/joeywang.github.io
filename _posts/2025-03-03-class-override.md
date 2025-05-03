---
layout: post
title: "Monkey-Patching: A Tale of Two Languages"
date: 2025-03-03 14:41:26 +0100
categories: [PHP, Ruby]
---

# Monkey-Patching: A Tale of Two Languages

## Introduction

Monkey-patching—also known as runtime method override or class reopening—is a technique that allows modifying or augmenting existing classes or modules at runtime. While it’s a powerful feature in some languages, it can be an anti-pattern in others. In this article, we explore why overriding class methods in PHP is risky and hard to revert, and contrast that with Ruby’s built-in, manageable approach.

---

## Thinking Critically about Overriding Class Methods

Before diving into language-specific mechanics, it’s useful to ask: why do developers override class methods at runtime in the first place—and when does it slip from a handy trick into an anti-pattern?

1. **Breaking Encapsulation:** By reaching inside and altering a class’s behavior post-definition, you violate its encapsulation. A class’s internal logic was designed to process inputs in a certain way; overriding methods circumvents that intent, making behavior unpredictable.

2. **Obscuring Intent:** Tests or patches that redefine methods inline can obscure what a class is supposed to do. Future maintainers may not realize that behavior has been monkey-patched, leading to debugging nightmares.

3. **Entrenching Technical Debt:** Quick fixes via runtime overrides often remain long after initial tests pass. Without explicit rollback mechanisms, these hacks can sneak into production, leaving legacy code that is difficult to trace or refactor.

4. **Encouraging Poor Design:** Reliance on runtime overrides can discourage proper design patterns (like dependency injection or interface-based architecture), since it offers a shortcut past designing flexible, testable classes.

5. **Test Isolation Issues:** As a special case of global state, method-level patches can leak between tests, making suites order-dependent and brittle—one of the hallmarks of an anti-pattern.

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

## Conclusion

While both PHP and Ruby support runtime method overrides, Ruby’s language design—open classes, aliasing, refinements, and integrated test-framework cleanup—makes monkey-patching a manageable tool rather than a dangerous hack. In PHP, by contrast, the lack of a built-in rollback facility and reliance on heavy extensions turns overrides into brittle anti-patterns.

Whenever possible, favor dependency injection and test doubles at the object level to keep your codebase clean, maintainable, and testable across both worlds.
