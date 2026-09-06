---
layout: post
title:  "Ruby Debugging in VS Code: Shopify LSP, rdbg, and RSpec"
description: "How to wire up VS Code for Ruby debugging with the Shopify Liquid LSP, the rdbg debugger from Ruby's debug gem, and launch configs for RSpec, Minitest, and Cucumber."
date:   2025-08-19 10:00:00 +0000
categories: [Rails]
tags: [ruby, debugging, testing, vscode, rspec, shopify]
---

VS Code's Ruby debugging only gets good once you wire up three separate things: language support for whatever you're actually editing, the `rdbg` debugger from Ruby's `debug` gem, and launch configs pointed at your test framework rather than at a plain script. Here's each piece.

## Prerequisites

You'll need:

- Visual Studio Code
- Ruby (preferably managed with a version manager like rbenv, rvm, or mise)
- A Ruby project to debug

## 1. Setting up the Shopify Language Server Protocol (LSP)

If you're working with Shopify themes or apps, the Shopify LSP gets you:

- Syntax highlighting
- Auto-completion
- Error detection
- Go-to-definition
- Documentation on hover

### Installation

1. First, install the Shopify theme CLI if you haven't already:

```bash
npm install -g @shopify/cli @shopify/theme
```

2. Install the Shopify Liquid extension for VS Code:
   - Open VS Code
   - Go to Extensions (Ctrl+Shift+X or Cmd+Shift+X)
   - Search for "Shopify Liquid" and install the official extension

3. For enhanced Ruby support in Shopify apps, install the Ruby LSP extension:
   - In VS Code Extensions, search for "Ruby LSP" and install the official extension

4. Configure your workspace settings by creating a `.vscode/settings.json` file in your project root:

```json
{
  "rubyLsp.formatter": "rubocop",
  "rubyLsp.linting": true,
  "rubyLsp.rubyVersionManager": "rbenv",
  "shopifyLiquid.enableLineFolding": true,
  "shopifyLiquid.enableSchemaPreview": true
}
```

### Shopify Theme Development

For Shopify theme development, the LSP will provide intelligent code completion and error checking for Liquid templates:

```liquid
{% assign product_count = collection.products_count %}
{% if product_count > 0 %}
  <p>There are {{ product_count }} products in this collection.</p>
{% endif %}
```

With the Shopify LSP, you'll get auto-completion for Liquid objects, filters, and tags, making theme development much more efficient.

## 2. Using rdbg from the debug gem

Ruby 3.1+ ships with the `debug` gem as the default debugger, which does more than `byebug` did. The `rdbg` command-line tool is how you drive it from outside an editor.

### Installation

Add the `debug` gem to your Gemfile:

```ruby
group :development, :test do
  gem 'debug', platforms: [:mri, :mingw, :x64_mingw]
end
```

Then run:

```bash
bundle install
```

### Basic Usage

To start debugging your Ruby application, you can insert a breakpoint in your code:

```ruby
# In your Ruby file
def calculate_total(items)
  debugger  # This will start the debugger
  items.sum(&:price)
end
```

When you run your application, execution will pause at the `debugger` line, and you'll enter the debugging session.

### Using rdbg command

You can also start your application with `rdbg`:

```bash
# For a Ruby script
rdbg my_script.rb

# For a Rails application
rdbg rails server

# For a Rails console
rdbg rails console
```

### VS Code Integration

To integrate `rdbg` with VS Code's debugging interface, you'll need to create a launch configuration. Create a `.vscode/launch.json` file in your project root:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "ruby",
      "name": "Rails server",
      "request": "launch",
      "program": "${workspaceRoot}/bin/rails",
      "args": ["server"],
      "env": {
        "DEBUGGER_STORED_RUBYLIB": ""
      }
    },
    {
      "type": "ruby",
      "name": "Debug Console",
      "request": "launch",
      "program": "${workspaceRoot}/bin/rails",
      "args": ["console"],
      "env": {
        "DEBUGGER_STORED_RUBYLIB": ""
      }
    },
    {
      "type": "ruby",
      "name": "Debug RSpec",
      "request": "launch",
      "program": "${workspaceRoot}/bin/rspec",
      "args": ["--pattern", "${relativeFile}"],
      "env": {
        "DEBUGGER_STORED_RUBYLIB": ""
      }
    }
  ]
}
```

### Debugging Commands

Once you're in a debugging session, you can use these common commands:

- `help` - Show available commands
- `next` or `n` - Execute the next line
- `step` or `s` - Step into method calls
- `continue` or `c` - Continue execution
- `break` or `b` - Set breakpoints
- `list` or `l` - Show current code
- `print` or `p` - Print variable values
- `pp` - Pretty print objects
- `exit` - Exit the debugger

## 3. Debugger Setup for RSpec and Testing Frameworks

A debugger in your test suite matters as much as one in application code, maybe more, since a failing test with no visibility into why is where you lose the most time.

### RSpec Configuration

First, ensure you have RSpec in your Gemfile:

```ruby
group :development, :test do
  gem 'rspec-rails'
  gem 'debug', platforms: [:mri, :mingw, :x64_mingw]
end
```

### Debugging Individual Tests

To debug a specific test, you can add a `debugger` statement directly in your test file:

```ruby
# spec/models/user_spec.rb
RSpec.describe User, type: :model do
  it "creates a valid user" do
    debugger  # Execution will pause here
    user = User.create(name: "John Doe", email: "john@example.com")
    expect(user).to be_valid
  end
end
```

Then run the specific test:

```bash
bundle exec rspec spec/models/user_spec.rb:4
```

### Using VS Code for Test Debugging

With the launch configuration we set up earlier, you can debug RSpec tests directly from VS Code:

1. Open your test file in VS Code
2. Set breakpoints by clicking in the gutter next to line numbers
3. Press F5 or go to Run > Start Debugging
4. Select "Debug RSpec" from the dropdown

### Advanced RSpec Debugging

For more complex debugging scenarios, you might want to debug the entire test suite or specific test groups:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "ruby",
      "name": "Debug Full RSpec Suite",
      "request": "launch",
      "program": "${workspaceRoot}/bin/rspec",
      "args": ["--format", "progress"],
      "env": {
        "DEBUGGER_STORED_RUBYLIB": ""
      }
    },
    {
      "type": "ruby",
      "name": "Debug Specific Tag",
      "request": "launch",
      "program": "${workspaceRoot}/bin/rspec",
      "args": ["--tag", "focus"],
      "env": {
        "DEBUGGER_STORED_RUBYLIB": ""
      }
    }
  ]
}
```

### Debugging with Other Testing Frameworks

#### Minitest

For Minitest, you can use a similar approach:

```ruby
# test/models/user_test.rb
require 'test_helper'

class UserTest < ActiveSupport::TestCase
  def test_user_creation
    debugger
    user = User.create(name: "John Doe", email: "john@example.com")
    assert user.valid?
  end
end
```

Add a launch configuration for Minitest:

```json
{
  "type": "ruby",
  "name": "Debug Minitest",
  "request": "launch",
  "program": "${workspaceRoot}/bin/rails",
  "args": ["test", "${relativeFile}"],
  "env": {
    "DEBUGGER_STORED_RUBYLIB": ""
  }
}
```

#### Cucumber

For Cucumber, add this to your launch configuration:

```json
{
  "type": "ruby",
  "name": "Debug Cucumber",
  "request": "launch",
  "program": "${workspaceRoot}/bin/cucumber",
  "args": ["${relativeFile}"],
  "env": {
    "DEBUGGER_STORED_RUBYLIB": ""
  }
}
```

## Remote Debugging

The `debug` gem also supports remote debugging, which is useful when debugging applications running in containers or on remote servers.

### Setting up Remote Debugging

Start your application with remote debugging enabled:

```bash
rdbg --open --port=12345 --host=0.0.0.0 rails server
```

Then connect to the debugger from another terminal:

```bash
rdbg --attach=localhost:12345
```

## Tips and Best Practices

1. **Use Conditional Breakpoints**: In VS Code, you can set conditional breakpoints that only trigger when certain conditions are met.

2. **Log Points**: Instead of stopping execution, you can use log points to print values to the debug console without pausing.

3. **Exception Breakpoints**: Configure your debugger to break when exceptions are raised, even if they're rescued.

4. **Performance Considerations**: The debugger adds overhead, so make sure to remove or disable breakpoints in production.

5. **Debugging in Production**: For production debugging, consider using logging-based approaches or tools like `rbtrace` instead of the full debugger.

## Troubleshooting Common Issues

### Debugger Not Starting

If the debugger isn't starting, check:

1. Ensure the `debug` gem is properly installed
2. Verify you're using Ruby 3.1 or later
3. Check that your VS Code Ruby extensions are up to date

### Breakpoints Not Being Hit

If breakpoints aren't being hit:

1. Make sure you're running in debug mode
2. Verify the file is being executed (add a `puts` statement to confirm)
3. Check that your launch configuration is correct

### Slow Debugging Performance

If debugging is slow:

1. Reduce the number of active breakpoints
2. Avoid stepping through large loops
3. Use `continue` to skip over uninteresting code sections

## The payoff

None of this is complicated on its own, the LSP, `rdbg`, and the launch configs are each a few lines of setup. What it buys you is being able to set a breakpoint in a Rails console session or an RSpec run and actually inspect state, instead of littering the code with `puts` and rerunning until the output tells you enough.