---
layout: post
title: Improve your productivity with irbrc
date: 2024-06-09 00:00 +0000
categories: Ruby
tags: irb
---

```ruby
begin
  require 'irbtools'
  require 'irb/completion'
  require 'awesome_print'
  require 'fancy_irb'
  FancyIrb.start
rescue LoadError => e
  puts e.messge
end

IRB.conf[:PROMPT][:DEV] = { # name of prompt mode
  :AUTO_INDENT => false,          # disables auto-indent mode
  :PROMPT_I =>  ">> ",            # simple prompt
  :PROMPT_S => nil,               # prompt for continuated strings
  :PROMPT_C => nil,               # prompt for continuated statement
  :RETURN => "    ==>%s\n"        # format to return value
}

IRB.conf[:PROMPT][:DOC] = { # name of prompt mode
  :AUTO_INDENT => false,          # disables auto-indent mode
  :PROMPT_I =>  ">> ",            # simple prompt
  :PROMPT_S => nil,               # prompt for continuated strings
  :PROMPT_C => nil,               # prompt for continuated statement
  :RETURN => "    ==>%s\n"        # format to return value
}


#IRB.conf[:PROMPT_MODE] = :MY_PROMPT
IRB.conf[:PROMPT_MODE] = :DOC

# Tracking and Debugging Helpers

# Log method calls with their arguments
# Usage: track_method_calls(User, :save)
def track_method_calls(klass, method_name)
  klass.class_eval do
    old_method = instance_method(method_name)
    define_method(method_name) do |*args, &block|
      puts "Calling #{klass}##{method_name} with args: #{args.inspect}"
      old_method.bind(self).call(*args, &block)
    end
  end
end

# Track SQL queries
# Usage: track_sql_queries
def track_sql_queries
  ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
    event = ActiveSupport::Notifications::Event.new(*args)
    puts "SQL Query: #{event.payload[:sql]}"
    puts "Duration: #{event.duration.round(2)} ms"
    puts "---"
  end
end

# Count method calls
# Usage: count_method_calls(User, :update)
def count_method_calls(klass, method_name)
  count = 0
  klass.class_eval do
    old_method = instance_method(method_name)
    define_method(method_name) do |*args, &block|
      count += 1
      puts "#{klass}##{method_name} called #{count} times"
      old_method.bind(self).call(*args, &block)
    end
  end
end

# Track object allocations
# Usage: track_allocations { your_code_here }
def track_allocations
  require 'objspace'
  GC.disable
  before = ObjectSpace.count_objects
  yield
  after = ObjectSpace.count_objects
  puts "Object allocations:"
  after.each do |key, value|
    diff = value - before[key]
    puts "  #{key}: #{diff}" if diff != 0
  end
ensure
  GC.enable
end

# Profile code execution
# Usage: profile_code { your_code_here }
def profile_code
  require 'ruby-prof'
  RubyProf.start
  yield
  result = RubyProf.stop
  printer = RubyProf::FlatPrinter.new(result)
  printer.print(STDOUT)
end

# Track method execution time
# Usage: track_time(User, :expensive_method)
def track_time(klass, method_name)
  klass.class_eval do
    old_method = instance_method(method_name)
    define_method(method_name) do |*args, &block|
      start_time = Time.now
      result = old_method.bind(self).call(*args, &block)
      end_time = Time.now
      puts "#{klass}##{method_name} took #{(end_time - start_time) * 1000.0} ms"
      result
    end
  end
end

# Log instance variable changes
# Usage: track_ivar_changes(user, :name)
def track_ivar_changes(object, ivar_name)
  object.define_singleton_method("#{ivar_name}=") do |value|
    old_value = instance_variable_get("@#{ivar_name}")
    instance_variable_set("@#{ivar_name}", value)
    puts "#{object.class}##{ivar_name} changed from #{old_value.inspect} to #{value.inspect}"
  end
end


# Memory usage tracker
# Usage: track_memory { your_code_here }
def track_memory
  memory_before = `ps -o rss= -p #{Process.pid}`.to_i
  yield
  memory_after = `ps -o rss= -p #{Process.pid}`.to_i
  puts "Memory usage increased by #{memory_after - memory_before} KB"
end


def compare_methods(count = 1, *methods)
  require 'benchmark'
  Benchmark.bmbm do |b|
    methods.each do |method|
      b.report(method) { count.times { send(method) } }
    end
  end
  nil
end

def pp_hash(hash, indent=1)
  hash.each do |k, v|
    print "  " * indent
    if v.is_a?(Hash)
      puts "#{k}:"
      pp_hash(v, indent+1)
    else
      puts "#{k}: #{v}"
    end
  end
end

def measure_allocation
  before = GC.stat(:total_allocated_objects)
  yield
  after = GC.stat(:total_allocated_objects)
  puts "Allocated objects: #{after - before}"
end

def http_get(url)
  require 'httparty'
  response = HTTParty.get(url)
  puts "Status: #{response.code}"
  puts "Body: #{response.body}"
end

def explore_relation(relation)
  puts "SQL: #{relation.to_sql}"
  puts "Explained:"
  puts relation.explain
end

def parse_json(json_string)
  require 'json'
  JSON.pretty_generate(JSON.parse(json_string))
end

def list_constants(mod)
  mod.constants.sort.each do |const|
    puts "#{const} = #{mod.const_get(const)}"
  end
end

# Usage: class_hierarchy(Array)
def class_hierarchy(klass)
  hierarchy = [klass]
  while (klass = klass.superclass)
    hierarchy << klass
  end
  hierarchy.each_with_index do |k, i|
    puts "#{' ' * i}#{k}"
  end
end

# Usage: method_info("hello", :upcase)
def method_info(obj, method_name)
  method = obj.method(method_name)
  puts "Name: #{method.name}"
  puts "Owner: #{method.owner}"
  puts "Parameters: #{method.parameters}"
  puts "Arity: #{method.arity}"
  puts "Source Location: #{method.source_location&.join(':')}"
end

def mixed_in_methods(klass, method = nil)
  if method.present?
    methods = [method]
  else
    methods = klass.methods
  end
  method_sources = methods.group_by { |m| klass.method(m).owner }

  method_sources.each do |source, methods|
    puts "#{source}: #{methods.count} methods"
    puts "  #{methods.take(5).join(', ')}..." if methods.any?
  end
end

# Usage: set_breakpoint(User, :save)
def set_breakpoint(klass, method_name)
  require 'pry'
  klass.send(:define_method, method_name) do |*args, &block|
    binding.pry
    super(*args, &block)
  end
end

# Usage: list_instance_variables(some_object)
def list_instance_variables(obj)
  obj.instance_variables.each do |var|
    puts "#{var}: #{obj.instance_variable_get(var).inspect}"
  end
end

# Usage: show_ancestors(Array)
def show_ancestors(klass)
  puts "Ancestors:"
  klass.ancestors.each { |ancestor| puts "  #{ancestor}" }
  puts "\nIncluded Modules:"
  (klass.ancestors - klass.superclass.ancestors - [klass]).each { |mod| puts "  #{mod}" }
end

# Usage: list_constants
def list_constants
  Module.constants.sort.each do |constant|
    puts constant
  end
end

# Usage: explore_methods("hello")
def explore_methods(obj)
  methods = {
    instance: obj.methods - Object.methods,
    inherited: obj.methods & Object.methods,
    singleton: obj.singleton_methods
  }

  methods.each do |category, method_list|
    puts "#{category.to_s.capitalize} methods:"
    method_list.sort.each { |method| puts "  #{method}" }
    puts
  end
end

# Usage: show_method_source(Array, :map)
def show_method_source(obj, method_name)
  require 'pry'
  obj.method(method_name).source.display
end

# Usage: list_classes
def list_classes
  Object.constants
    .select { |c| Object.const_get(c).is_a? Class }
    .sort
    .each { |klass| puts klass }
end

# Usage: method_location(Array, :map)
def method_location(obj, method_name)
  file, line = obj.method(method_name).source_location
  puts "Defined in #{file}:#{line}"
end

# Usage: subclasses_of(ActiveRecord::Base)
def subclasses_of(klass)
  ObjectSpace.each_object(Class).select { |k| k < klass }
end

def track_changes(target, method_name)
  original_value = target.send(method_name.to_s.sub('=', ''))
  puts "Starting to track changes to #{target}.#{method_name}"
  puts "Initial value: #{original_value.class}"

  trace = TracePoint.new(:line) do |tp|
    #next unless tp.method_id.to_s == method_name.to_s && tp.self.instance_of?(target.class) && tp.self == target
    next unless tp.self.instance_of?(target.class) && tp.self == target && tp.method_id.to_s.include?(method_name.to_s.sub('=', ''))

    current_value = target.send(method_name.to_s.sub('=', ''))
    if current_value != original_value
      puts "\nChange detected in #{target}.#{method_name}:"
      puts "  From: #{original_value.class}"
      puts "  To:   #{current_value.class}"
      puts "  At:   #{tp.path}:#{tp.lineno}"
      puts "  Backtrace:"
      puts caller[0..5].map { |line| "    #{line}" }
      puts '-'*60
      original_value = current_value
    end
  end

  trace.enable
  puts "Tracking enabled. Run 'trace.disable' to stop tracking."
  
  trace  # Return the trace object so it can be disabled later
end

def track_method(klass, method_name, process=nil)
  trace = TracePoint.new(:call) do |tp|
    next unless tp.method_id.to_s == method_name.to_s

    next unless (klass.is_a?(Class) ? tp.self.is_a?(klass) : tp.self == klass)

    puts '-'*20
    puts "#{tp.path}:#{tp.lineno}"
    puts "#{tp.defined_class}##{tp.method_id}" if tp.defined_class
    process.call if process
  end

  trace.enable
  if block_given?
    yield
    trace.disable
  else
    puts "Tracking enabled. Run 'trace.disable' to stop tracking."
  end

  trace  # Return the trace object so it can be disabled later
end

# https://gist.github.com/brainlid/2721486
# Net::HTTP.enable_debug!
# Net::HTTP.disable_debug!
require 'net/http'
module Net
  class HTTP
    def self.enable_debug!
      raise "You don't want to do this in anything but development mode!" unless Rails.env == 'development'
      class << self
        alias_method :__new__, :new
        def new(*args, &blk)
          instance = __new__(*args, &blk)
          instance.set_debug_output($stderr)
          instance
        end
      end
    end

    def self.disable_debug!
      class << self
        alias_method :new, :__new__
        remove_method :__new__
      end
    end
  end
end
```
