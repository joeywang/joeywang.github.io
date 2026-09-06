---
layout: post
title: "Why Kaminari's Anonymous Modules Break Rails Caching"
description: "Why Rails caching raises TypeError: can't dump anonymous module with Kaminari-paginated collections, and how to trace and fix the module causing it."
date: 2024-10-17 00:00 +0000
categories: [Rails]
tags: [ruby, rails, kaminari, debugging]
---
<audio controls preload="metadata" src="/assets/audio/dive-into-kaminari-anonymous-modules-summary.ogg">
  Your browser does not support the audio element.
</audio>


`TypeError: can't dump anonymous module` is one of those Rails cache errors that gives you no clue where to look. It shows up when something you're caching includes a module with no name, and Kaminari is a common source of exactly that.

## What makes a module anonymous

Ruby modules are usually declared with a name:

```ruby
module NamedModule
  def some_method
    "Hello"
  end
end
```

`Module.new` skips the name entirely:

```ruby
Module.new do
  def some_method
    "Hello"
  end
end
```

Anonymous modules show up a lot in metaprogramming: dynamic trait composition, mixins built at runtime, concerns that configure themselves based on other state.

## Why Marshal can't serialize them

Rails' default cache serializer is `Marshal`, and it refuses anonymous modules for a structural reason, not an arbitrary one: it dumps objects by reference where it can, and a module's reference is its constant name.

```ruby
module Named
  def method; end
end
Marshal.dump(Named) # fine, there's a constant to point to

anonymous = Module.new { def method; end }
Marshal.dump(anonymous) # TypeError: can't dump anonymous module
```

No name also means no guaranteed identity. `3.times { Module.new { def method; end } }` creates three distinct modules with identical bodies. There's no name Marshal could restore that would tell you which one you're getting back, or whether the module still exists in the same form when you load it later.

## Where Kaminari creates one

Kaminari builds part of its pagination behavior with dynamically generated modules:

```ruby
module Kaminari
  module PageScopeMethods
    Kaminari.config.instance_values.each do |key, value|
      Module.new do
        define_method(key) { value }
      end
    end
  end
end
```

Cache a paginated collection directly, and that anonymous module comes along for the ride:

```ruby
Rails.cache.write('posts', Post.page(1))
# TypeError: can't dump anonymous module
```

## Finding the module that's causing it

A few ways to see what's anonymous and where it's coming from, roughly in order of how much digging you need:

Trace module creation as it happens:

```ruby
module ModuleTracker
  def self.trace_module_creation
    TracePoint.new(:class) do |tp|
      if tp.self.is_a?(Module) && tp.self.name.nil?
        puts "Anonymous module created at:"
        puts "Location: #{tp.path}:#{tp.lineno}"
        puts "Backtrace:\n#{caller.join("\n")}"
      end
    end.enable
  end
end

ModuleTracker.trace_module_creation
Post.page(1) # shows the module creation trace
```

Search object space for existing anonymous modules:

```ruby
module AnonymousModuleFinder
  def self.find_anonymous_modules
    ObjectSpace.each_object(Module).select { |mod| mod.name.nil? }
  end

  def self.find_including_classes(mod)
    ObjectSpace.each_object(Class).select do |klass|
      klass.included_modules.include?(mod)
    end
  end
end
```

Catch the error at the point of caching, and dump what was being cached:

```ruby
module CacheDebugger
  def write(name, value, options = nil)
    super
  rescue TypeError => e
    if e.message.include?('anonymous')
      puts "Failed to cache: #{value.class}"
      value.included_modules.each { |mod| puts "- #{mod.name || '<anonymous>'}" }
      raise
    end
  end
end

Rails.cache.extend(CacheDebugger)
```

That last one is usually the fastest path: it names the object and the included module that triggered the failure, instead of leaving you to guess from a stack trace that just points at `Marshal.dump`.

## Fixing it

Once you know where the anonymous module comes from, there are three real options, in order of how invasive they are:

1. **Cache the data, not the collection.** Almost always the right fix: `Rails.cache.fetch('posts') { Post.page(1).map { |p| { id: p.id, title: p.title } } }`. You rarely need to cache an ActiveRecord relation object; you need the data it would return.
2. **Switch the cache serializer to JSON**, if you control the cache store: `config.cache_store = :memory_store, serializer: JSON`. This sidesteps the whole class of Marshal-specific failures, at the cost of losing Marshal's ability to round-trip arbitrary Ruby objects.
3. **Replace the dynamic module with a named one or a plain method**, if you're the one generating it. A `Module.new` inside a loop is rarely necessary; a named module or a regular class method usually does the same job without creating an object that can't be serialized.

Anonymous modules aren't a mistake by themselves; plenty of legitimate metaprogramming uses them. The mistake is caching an object that happens to include one, without noticing until Marshal refuses it in production.
