---
layout: post
title:  "How to Set a Breakpoint on Devise's current_user Method"
description: "Why byebug can't break on Devise's metaprogrammed current_user method, and several ways to debug or patch a method that isn't in your source."
date:   2024-05-08 14:41:26 +0100
categories: [Rails]
tags: [rails, ruby, debugging, metaprogramming, devise]
---

<audio controls preload="metadata" src="/assets/audio/devise-metaprogramming-debugging-summary.ogg">
  Your browser does not support the audio element.
</audio>


Devise is a Rails authentication framework built on Warden. It gives you `current_user` (and `current_admin`, or `current_whatever` for any model you configure) without writing that method yourself, because it generates it dynamically for every model you set up for authentication.

That's convenient right up until you need to set a breakpoint inside `current_user` and byebug refuses to stop there.

## Why byebug can't find the method

`current_user` doesn't exist in Devise's source the way you'd expect. What's actually there is a template:

```ruby
def #{mapping}_signed_in?
  !!current_#{mapping}
end

def current_#{mapping}
  @current_#{mapping} ||= warden.authenticate(scope: :#{mapping})
end
```

Devise interpolates `mapping` (`user`, `admin`, whatever you configured) and defines the real method at runtime with `define_method`. The file and line byebug is looking at is the template, not the generated method, so a breakpoint set there never fires.

## The debug gem handles this correctly

Ruby 3.1 made `debug` the standard replacement for `byebug`, and it can set breakpoints on methods defined at runtime, which byebug cannot. It's also faster and supports remote debugging out of the box.

```ruby
# Gemfile
gem 'debug', '>= 1.0.0'
```

```ruby
def some_method
  debugger
  # rest of the method
end
```

Or start it from the command line with `rails server --debugger`, then break on the dynamically generated method directly:

```ruby
debugger.break MyController, :current_user
```

The trade-off is mostly familiarity: if your muscle memory is byebug commands, there's a short relearning curve, and as of early Rails 7 some byebug-specific integrations hadn't fully caught up.

## Wrapping the method yourself when a debugger won't do

Sometimes you want more than a breakpoint: you want to log every call, or trace what's calling `current_user` and from where. Ruby's metaprogramming gives you a few ways to swap the method temporarily and put it back.

**Dynamic replacement**, from outside the method:

```ruby
# Get the original method
original_method = method(:current_user)

# Define a new method with debugging
new_method = proc do |*args|
  puts "Entering current_user"
  result = original_method.call(*args)
  puts "Result: #{result.inspect}"
  debugger # or binding.pry
  result
end

# Replace the original method
define_method(:current_user, new_method)

# ... debugging ...

# Restore the original method
define_method(:current_user, original_method)
```

From inside the method itself, `__method__` gets you the name without hardcoding it:

```ruby
# Assuming we're inside the original current_user method

# Get the current method object
current_method = method(__method__)

# Define the new method
new_method = proc do |*args|
  puts "Entering modified current_user method"
  result = current_method.call(*args)
  puts "current_user result: #{result.inspect}"
  # debugger
  result
end

# Replace the method
self.class.send(:define_method, __method__, new_method)
self.class.send(:define_method, "old_#{__method__}", current_method)

# Restore the old method
old_method = method("old_#{__method__}")
self.class.send(:define_method, __method__, old_method)

self.class.send(:undef_method, "old_#{__method__}")

# Call the new method to continue execution
new_method.call
```

To restore the original afterward, either keep a reference to it as above, or pull it back from the superclass with `superclass.instance_method`.

### Using alias_method

`alias_method` is the least ceremony for a quick, reversible wrap:

```ruby
class ApplicationController < ActionController::Base
  # Create an alias for the original method
  alias_method :original_current_user, :current_user

  # Redefine current_user with debugging
  def current_user
    puts "Entering current_user method"
    result = original_current_user
    puts "current_user result: #{result.inspect}"
    debugger # or binding.pry
    result
  end
end
```

Restore it the same way you set it up:

```ruby
class ApplicationController < ActionController::Base
  alias_method :current_user, :original_current_user
  remove_method :original_current_user
end
```

Or, using the instance method captured beforehand:

```ruby
class ApplicationController < ActionController::Base
  original_method = instance_method(:current_user)
  undef_method :current_user
  define_method :current_user, original_method
end
```

`alias_method` keeps the method's visibility (public, protected, or private), has a negligible performance cost, and only affects the class you define it in, not a superclass. Set the alias before any code calls the original method, or you'll wrap nothing.

### Using prepend and refine

`prepend` adds a module ahead of the class in the method lookup chain, so it modifies behavior across the whole hierarchy and cleans up with `super`:

```ruby
module DebuggingModule
  def current_user
    puts "Entering current_user method"
    result = super
    puts "current_user result: #{result.inspect}"
    debugger # or binding.pry
    result
  end
end

class ApplicationController < ActionController::Base
  prepend DebuggingModule
end
```

`refine` scopes the change to wherever you `using` it, which makes it the safest option when you only want the modified behavior in one file:

```ruby
module DebuggingRefinements
  refine ApplicationController do
    def current_user
      puts "Entering current_user method"
      result = super
      puts "current_user result: #{result.inspect}"
      debugger # or binding.pry
      result
    end
  end
end

# In the file or context where you want to use the debugging version:
using DebuggingRefinements

# The refined version of current_user will only be active in this file or block
```

## Which one to reach for

`alias_method` for a quick, reversible check. `prepend` when you want the change everywhere the class is used. `refine` when you want it nowhere else. Dynamic `define_method` replacement when you need the most control and are willing to manage restoring the original method yourself.

All four exist because Devise, and plenty of other gems, generate real methods at runtime. Understanding that is what makes the rest of Ruby's metaprogramming toolbox make sense, not just debugging Devise.
