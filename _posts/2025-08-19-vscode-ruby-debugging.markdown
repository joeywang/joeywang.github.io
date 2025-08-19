---
layout: post
title:  "Mastering Ruby Debugging in VS Code: Shopify, rdbg, and RSpec Setup"
date:   2025-08-19 10:00:00 +0000
categories: Ruby VSCode Debugging
tags: [ruby, vscode, debugging, shopify, rspec, rdbg]
---

# Mastering Ruby Debugging in VS Code: Shopify, rdbg, and RSpec Setup

Debugging is an essential part of any developer's workflow, and having a solid debugging setup can significantly improve your productivity. In this article, we'll explore how to configure Visual Studio Code for debugging Ruby applications, with a special focus on three key areas:

1. Setting up the Shopify Language Server Protocol (LSP)
2. Using the `rdbg` debugger from the `debug` gem
3. Configuring the debugger for RSpec and other testing frameworks

Whether you're working on a standard Ruby on Rails application or a Shopify theme/plugin, these techniques will help you debug your code more effectively.

## Prerequisites

Before we dive in, make sure you have the following installed:

- Visual Studio Code
- Ruby (preferably managed with a version manager like rbenv, rvm, or mise)
- A Ruby project to debug (we'll use a simple example)

## 1. Setting up the Shopify Language Server Protocol (LSP)

If you're working with Shopify themes or apps, setting up the Shopify LSP will greatly enhance your development experience with features like:

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

Ruby 3.1+ comes with the `debug` gem as the default debugger, which provides a more powerful debugging experience than the older `byebug`. The `rdbg` command-line tool allows you to debug your Ruby applications effectively.

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

Setting up debugging for your test suite is crucial for test-driven development and troubleshooting failing tests.

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

## Conclusion

Setting up an effective debugging environment in VS Code for Ruby development can significantly improve your productivity. With the Shopify LSP, `rdbg` from the `debug` gem, and proper configurations for RSpec and other testing frameworks, you'll have a powerful toolkit for diagnosing and fixing issues in your Ruby applications.

Remember that debugging is a skill that improves with practice. The more familiar you become with these tools and techniques, the more efficient you'll be at identifying and resolving issues in your code. Happy debugging!