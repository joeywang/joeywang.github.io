---
layout: post
title: "How Rails Loads Your App: Rake, Console, Server, and Tests"
description: "What Rails actually loads when you run a rake task, the console, the server, or tests, and how to load rake tasks in each environment when you need them."
date: 2024-01-04 00:00 +0000
categories: [Rails]
tags: [rails, ruby, testing, debugging]
---
<audio controls preload="metadata" src="/assets/audio/rake-test-console-and-server-understanding-the-differences-summary.ogg">
  Your browser does not support the audio element.
</audio>


A rake task that works fine on my machine fails in CI because a constant is not defined. A console session can call a model method that a rake task cannot. The difference is not magic: `rake`, `rails console`, `rails server`, and the test runner each load a different slice of the application. Knowing which slice saves real debugging time.

## Rake tasks load only what they ask for

Rake is Ruby's build tool, and Rails leans on it for migrations, data fixes, and scheduled jobs. A rake task does not get the full Rails environment for free. It gets whatever its prerequisites load. A task that declares `task my_task: :environment` boots the whole app; a task without that dependency runs with almost nothing.

That is a deliberate design. A task that only touches the filesystem should not pay the cost of booting Rails, and tasks that manage their own dependencies can run in isolation without side effects from app initialization. It is also the usual source of "uninitialized constant" errors in rake tasks: the `:environment` dependency is missing.

## The console and the server load everything

`rails console` boots the full application. That is the point of it: you want to poke at models, run queries, and reproduce bugs in the same context the app runs in.

`rails server` also loads everything, for a different reason. It has to handle arbitrary requests, run the middleware stack, and manage sessions, so there is no useful subset to load.

## Tests load everything too

`rails test` and `rspec` boot the full Rails environment in test mode. Tests are only trustworthy if they run against the same wiring as production: the same initializers, the same middleware, the same database adapter. The cost is boot time, which is why tools like Spring exist.

## Loading rake tasks where they are not loaded

The one asymmetry worth remembering: the console, the server, and tests do not load your rake task definitions, even though they load everything else.

### In the console

Load the tasks first, then invoke:

```ruby
irb(main):001:0> Rails.application.load_tasks
irb(main):002:0> Rake::Task['my:rake:task'].invoke
```

### In the server

You can technically invoke a rake task from a controller action:

```ruby
# app/controllers/example_controller.rb
class ExampleController < ApplicationController
  def some_action
    Rake::Task['my:rake:task'].invoke
    # ...
  end
end
```

Don't do this in anything real. It couples an HTTP request to work that belongs in a background job, and `invoke` only runs once per process unless you `reenable` the task. It is listed here because it comes up in debugging, not because it is a pattern.

### In tests

If you are testing a rake task itself, load the tasks in your test helper and invoke them like any other code:

```ruby
# test/test_helper.rb or spec/rails_helper.rb
require 'rake'
Rails.application.load_tasks
```

```ruby
# test/lib/tasks/my_rake_task_test.rb
require 'test_helper'

class MyRakeTaskTest < ActiveSupport::TestCase
  test "invoke rake task" do
    Rake::Task['my:rake:task'].invoke
    # assert on the task's effects
  end
end
```

One gotcha: `Rake::Task#invoke` respects prerequisites and only runs once. In a test suite that invokes the same task in several tests, call `Rake::Task['my:rake:task'].reenable` between invocations.

## The principle

Rake loads what the task declares, everything else loads the whole app, and nothing loads your rake tasks except rake itself. Most confusing failures in this area reduce to one of those three facts.
