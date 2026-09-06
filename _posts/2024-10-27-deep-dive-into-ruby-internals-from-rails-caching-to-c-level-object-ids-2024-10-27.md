---
layout: post
title: "Ruby object IDs, anonymous modules, and Rails cache errors"
description: "A Rails.cache TypeError on an anonymous module led into Ruby's Marshal restrictions and the relationship between object_id and C-level memory addresses."
date: 2024-10-27 12:13 +0000
categories: [Rails]
tags: [ruby, rails, debugging]
---

<audio controls preload="metadata" src="/assets/audio/deep-dive-into-ruby-internals-from-rails-caching-to-c-level-object-ids-2024-10-27-summary.ogg">
  Your browser does not support the audio element.
</audio>


A one-line Rails caching call broke with a cryptic error, and chasing it down led somewhere more interesting than the caching bug itself.

## The bug

```ruby
Rails.cache.write(Lesson.page(1))
```

with Kaminari handling pagination, threw:

```
TypeError: can't dump anonymous module #<Module:0x000000012028d860>
```

## Why an anonymous module is unmarshalable

The error comes from `Marshal`, Ruby's built-in serializer. Marshal can dump a named constant like a class or module because it stores the name and looks it up again on load. An anonymous module has no name to serialize:

```ruby
Marshal.dump(String)               # fine, String has a name

Marshal.dump(Module.new)           # TypeError: can't dump anonymous module
```

Kaminari's paginated relation carries one of these anonymous modules internally, used for method injection, and `Rails.cache.write` marshals its argument before writing it. That's the whole bug: cache a paginated relation, get a `TypeError`, because part of what you're caching can't be named.

## Finding the module with rdbg

Ruby's built-in debugger made the anonymous module visible directly:

```ruby
require 'debug'
catch TypeError do
  Rails.cache.write(Lesson.page(1))
end
```

```
(rdbg) p self
#<Module:0x000000012028d860>
```

There's no Ruby source to jump to for this module. It was built at the C level, not defined anywhere in the codebase, which is why grepping for it turns up nothing.

```ruby
p SomeModule.name                    # "SomeModule" for a named module
p anonymous_mod.name                 # nil
p anonymous_mod.object_id            # some integer, e.g. 8980
```

## object_id and the C-level address

The debugger session surfaced something worth remembering on its own: the relationship between Ruby's `object_id` and the object's actual memory address.

```
(rdbg) self
#<Module:0x000000012029fb50>
(rdbg) object_id
8980
```

For a regular, heap-allocated object, `object_id * 2` approximates the hex address MRI prints for it:

```ruby
obj = ObjectSpace._id2ref(8980)
hex_addr = "0x%016x" % (obj.object_id * 2)
```

Immediate values, small integers and symbols, don't have a backing heap object at all, so their `object_id` encodes the value directly rather than an address:

```ruby
42.object_id   # 85 == 42 * 2 + 1
```

You can watch allocation happen in real time with `ObjectSpace`:

```ruby
require 'objspace'
ObjectSpace.trace_object_allocations do
  obj = Object.new
  p ObjectSpace.allocation_sourcefile(obj)
  p ObjectSpace.allocation_sourceline(obj)
end
```

## The takeaway

The practical fix was mundane: don't `Marshal.dump` something that might be carrying an anonymous module, or serialize a plain representation of the data instead of the live relation. The interesting part was incidental: `object_id` isn't an opaque token, it's derived from the same memory address the debugger prints, except for immediate values, which never had an address to derive it from. Knowing that distinction is what makes `object_id` output make sense the next time a debugger session shows you a number that looks meaningless.
