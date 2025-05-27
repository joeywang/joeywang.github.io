---
layout: post
title: "Debugging Dynamic Library Conflicts in Ruby: The Nokogiri libxml2 Mystery"
date: "2025-04-22"
categories: [libxml2, ruby, rubygems]
tags: [nokogiri, ruby, rubygems]
---

# Debugging Dynamic Library Conflicts in Ruby: The Nokogiri libxml2 Mystery

*A deep dive into resolving dynamic library version conflicts between gems in containerized Ruby applications*

## The Problem: When Tests Pass Locally But Fail in Production

Picture this: your Rails tests pass perfectly on your M1 MacBook, but fail mysteriously in your Docker container with cryptic XPath syntax errors:

```
Nokogiri::XML::XPath::SyntaxError: ERROR: Invalid expression: .//*:a | self::*:a
```

The XPath expression is valid, so what's going on? This is the story of a debugging journey that reveals the hidden complexity of dynamic library loading in Ruby applications.

## The Warning That Tells the Whole Story

Buried in the logs was a crucial warning message:

```
WARNING: Nokogiri was built against libxml version 2.13.8, but has dynamically loaded 2.9.14
```

This single line reveals the entire problem: **Nokogiri was compiled against one version of libxml2 but is running against a completely different version at runtime**. The newer XPath syntax in libxml 2.13.8 isn't supported by the older 2.9.14 version that's actually being used.

## Understanding Ruby Extension Loading

To debug this properly, we need to understand how Ruby loads native extensions:

### The Loading Process

1. **Ruby finds the extension**: When you `require 'nokogiri'`, Ruby searches `$LOAD_PATH` for `nokogiri.rb` or `nokogiri.so`
2. **Dynamic loading**: Ruby calls `dlopen()` to load the shared library
3. **Dependency resolution**: The system's dynamic linker resolves all C library dependencies
4. **Symbol binding**: Function calls get bound to the loaded libraries

The problem occurs in step 3 - the dynamic linker can load a different version of libxml2 than what Nokogiri expects.

## Detective Work: Tracing the Problem

### Platform Differences Provide the First Clue

```bash
# Local machine (M1 Mac)
$ ruby -e 'puts Gem::Platform.local.to_s'
arm64-darwin-24

# Production container (Linux)
$ ruby -e 'puts Gem::Platform.local.to_s'  
x86_64-linux-gnu
```

Different platforms mean different pre-compiled gems with different linking strategies.

### Using ldd to Inspect Dependencies

```bash
$ ldd ./lib/nokogiri/3.4/nokogiri.so
linux-vdso.so.1 (0x00007ffe8ed31000)
libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (0x00007acf1d7af000)
libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2 (0x00007acf1d7aa000)
libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0 (0x00007acf1d7a5000)
libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x00007acf1d5c2000)
/lib64/ld-linux-x86-64.so.2 (0x00007acf1dac0000)
```

Surprisingly, `ldd` shows no direct libxml2 dependency. This suggests either static linking or indirect loading.

### The Smoking Gun: LD_DEBUG

The real breakthrough came from using `LD_DEBUG` to trace dynamic library loading:

```bash
$ LD_DEBUG=libs ruby -rnokogiri -e "puts 'loaded'" 2>&1 | grep libxml2
file=/lib/x86_64-linux-gnu/libxml2.so.2 [0]; needed by nokogiri.so [0] (relocation dependency)
```

**Relocation dependency** - the key insight! Nokogiri doesn't directly link to libxml2, but needs it for symbol resolution at runtime.

## The Root Cause: Indirect Library Loading

The issue becomes clear when we trace what happens when multiple gems are loaded:

1. **ruby-vips** loads first and brings in system `libxml2.so.2` (version 2.9.14)
2. **Nokogiri** loads later and finds libxml2 symbols already resolved
3. **Dynamic linker** binds Nokogiri's calls to the wrong libxml2 version
4. **XPath expressions** compiled for libxml 2.13.8 syntax fail against 2.9.14

### Visualizing the Conflict

```
┌─────────────┐    ┌──────────────┐    ┌─────────────────┐
│ ruby-vips   │───▶│ system vips  │───▶│ libxml2 v2.9.14 │
└─────────────┘    └──────────────┘    └─────────────────┘
                                                │
                                                ▼
┌─────────────┐                        ┌─────────────────┐
│ nokogiri    │───────────────────────▶│ ❌ Wrong version│
│(built for   │                        │   libxml2       │
│ v2.13.8)    │                        │   v2.9.14       │
└─────────────┘                        └─────────────────┘
```

## Debugging Techniques and Tools

### Essential Commands for Library Debugging

**Trace all library loading:**
```bash
LD_DEBUG=libs,files ruby -rnokogiri -e "puts 'loaded'" 2>&1 | grep xml
```

**See what's loaded at runtime:**
```bash
lsof -p $(pgrep ruby) | grep libxml
```

**Check symbol resolution:**
```bash
LD_DEBUG=symbols ruby -rnokogiri -e "Nokogiri::XML('<test/>')" 2>&1 | grep xml
```

**Inspect gem contents:**
```bash
find $(gem which nokogiri | xargs dirname) -name "*.so" -exec ldd {} \;
```

### Ruby-Level Debugging

```ruby
require 'nokogiri'
puts "Runtime version: #{Nokogiri::XML::LIBXML_VERSION}"
puts "Compiled version: #{Nokogiri::XML::LIBXML_COMPILED_VERSION}"
puts "Version info:"
puts Nokogiri::VERSION_INFO.to_yaml
```

## Shortening the Feedback Loop: Debug-First Approach

When debugging library conflicts in CI/CD environments, the key is to **gather information quickly** without endless commit-test cycles. Here's how to efficiently debug in GitHub Actions or other CI systems:

### 1. Add Debug Code to Your Application

Create a dedicated debug script that you can easily enable/disable:

```ruby
# lib/debug/library_inspector.rb
class LibraryInspector
  def self.inspect_environment
    puts "=== ENVIRONMENT DEBUG ==="
    puts "Platform: #{Gem::Platform.local}"
    puts "Ruby version: #{RUBY_VERSION}"
    puts "Architecture: #{RbConfig::CONFIG['target_cpu']}"
    puts
    
    inspect_nokogiri if defined?(Nokogiri)
    inspect_loaded_libraries
    inspect_library_paths
  end
  
  def self.inspect_nokogiri
    puts "=== NOKOGIRI DEBUG ==="
    puts "Nokogiri version: #{Nokogiri::VERSION}"
    puts "Compiled against libxml: #{Nokogiri::XML::LIBXML_COMPILED_VERSION}"
    puts "Runtime libxml version: #{Nokogiri::XML::LIBXML_VERSION}"
    puts "Version mismatch: #{Nokogiri::XML::LIBXML_VERSION != Nokogiri::XML::LIBXML_COMPILED_VERSION}"
    puts
    puts "Nokogiri full version info:"
    puts Nokogiri::VERSION_INFO.to_yaml
    puts
  end
  
  def self.inspect_loaded_libraries
    puts "=== LOADED LIBRARIES ==="
    
    # Get current process PID in a portable way
    pid = Process.pid
    
    # Try different methods to inspect loaded libraries
    if File.exist?("/proc/#{pid}/maps")
      puts "Libraries containing 'xml':"
      system("grep -i xml /proc/#{pid}/maps || echo 'No XML libraries found in maps'")
      puts
    end
    
    # Check lsof if available
    if system("which lsof > /dev/null 2>&1")
      puts "Open files containing 'xml':"
      system("lsof -p #{pid} 2>/dev/null | grep -i xml || echo 'No XML files found via lsof'")
      puts
    end
  end
  
  def self.inspect_library_paths
    puts "=== LIBRARY PATHS ==="
    puts "LD_LIBRARY_PATH: #{ENV['LD_LIBRARY_PATH'] || 'not set'}"
    puts "Ruby load path (first 5 entries):"
    $LOAD_PATH.first(5).each { |path| puts "  #{path}" }
    puts
    
    # Find nokogiri installation
    if defined?(Nokogiri)
      nokogiri_path = Gem.loaded_specs['nokogiri']&.full_gem_path
      puts "Nokogiri gem path: #{nokogiri_path}" if nokogiri_path
      
      if nokogiri_path
        puts "Nokogiri lib contents:"
        Dir.glob("#{nokogiri_path}/**/*.so").each do |so_file|
          puts "  #{so_file}"
          # Show dependencies if ldd is available
          if system("which ldd > /dev/null 2>&1")
            puts "    Dependencies:"
            system("ldd '#{so_file}' 2>/dev/null | grep -E '(xml|vips)' | sed 's/^/      /' || echo '      No xml/vips dependencies'")
          end
        end
      end
    end
    puts
  end
end
```

### 2. Add Conditional Debug Loading

Add this to your test helper or application initialization:

```ruby
# test/test_helper.rb or config/application.rb
if ENV['DEBUG_LIBRARIES'] == 'true'
  require_relative '../lib/debug/library_inspector'
  
  # Load gems in the order you want to test
  puts "Loading gems..."
  require 'ruby-vips' if ENV['LOAD_VIPS'] == 'true'
  require 'nokogiri'
  
  # Inspect after loading
  LibraryInspector.inspect_environment
  
  # Test a simple operation to see if it works
  begin
    doc = Nokogiri::XML('<test><a href="example">link</a></test>')
    links = doc.xpath('.//*:a | self::*:a')  # The failing XPath
    puts "XPath test: SUCCESS - found #{links.length} links"
  rescue => e
    puts "XPath test: FAILED - #{e.class}: #{e.message}"
  end
  
  puts "=== END DEBUG ==="
end
```

### 3. GitHub Actions Workflow for Quick Debugging

Create a dedicated workflow file for debugging:

```yaml
# .github/workflows/debug-libraries.yml
name: Debug Library Loading

on:
  workflow_dispatch:  # Manual trigger
    inputs:
      load_vips:
        description: 'Load ruby-vips before nokogiri'
        required: false
        default: 'false'
        type: choice
        options:
        - 'true'
        - 'false'
      debug_level:
        description: 'Debug verbosity level'
        required: false
        default: 'basic'
        type: choice
        options:
        - 'basic'
        - 'verbose'
        - 'trace'

jobs:
  debug:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        ruby-version: '3.4'
        bundler-cache: true
    
    - name: System Information
      run: |
        echo "=== SYSTEM INFO ==="
        uname -a
        lsb_release -a || echo "lsb_release not available"
        
        echo "=== LIBXML2 SYSTEM VERSION ==="
        pkg-config --modversion libxml-2.0 || echo "pkg-config not available"
        dpkg -l | grep libxml2 || echo "No libxml2 packages found"
        find /usr -name "*libxml2*" 2>/dev/null | head -10 || echo "No libxml2 files found"
    
    - name: Ruby Environment
      run: |
        echo "=== RUBY ENVIRONMENT ==="
        ruby -v
        gem -v
        bundle -v
        ruby -e "puts Gem::Platform.local"
        
    - name: Gem Information
      run: |
        echo "=== GEM VERSIONS ==="
        bundle list | grep -E "(nokogiri|vips)"
        
        echo "=== NOKOGIRI GEM DETAILS ==="
        bundle show nokogiri
        find $(bundle show nokogiri) -name "*.so" -exec file {} \;
        
    - name: Basic Debug
      env:
        DEBUG_LIBRARIES: 'true'
        LOAD_VIPS: ${{ github.event.inputs.load_vips }}
      run: |
        ruby -e "
          puts 'Loading with DEBUG_LIBRARIES=true...'
          load './test/test_helper.rb'  # or wherever you put the debug code
        "
    
    - name: Verbose Debug (if requested)
      if: github.event.inputs.debug_level == 'verbose' || github.event.inputs.debug_level == 'trace'
      env:
        LD_DEBUG: files,libs
      run: |
        echo "=== VERBOSE LIBRARY LOADING ==="
        ruby -rnokogiri -e "puts 'Nokogiri loaded'" 2>&1 | grep -i xml || echo "No XML-related output"
    
    - name: Trace Debug (if requested)
      if: github.event.inputs.debug_level == 'trace'
      run: |
        echo "=== TRACE LIBRARY LOADING ==="
        strace -e trace=openat ruby -rnokogiri -e "puts 'loaded'" 2>&1 | grep -i xml || echo "No XML files opened"
        
    - name: Test Different Load Orders
      run: |
        echo "=== TESTING LOAD ORDERS ==="
        
        echo "Test 1: Nokogiri first"
        ruby -e "
          require 'nokogiri'
          require 'ruby-vips' rescue puts 'ruby-vips not available'
          puts 'Runtime: ' + Nokogiri::XML::LIBXML_VERSION
          puts 'Compiled: ' + Nokogiri::XML::LIBXML_COMPILED_VERSION
        " || echo "Test 1 failed"
        
        echo "Test 2: ruby-vips first"
        ruby -e "
          require 'ruby-vips' rescue puts 'ruby-vips not available'
          require 'nokogiri'
          puts 'Runtime: ' + Nokogiri::XML::LIBXML_VERSION
          puts 'Compiled: ' + Nokogiri::XML::LIBXML_COMPILED_VERSION
        " || echo "Test 2 failed"
    
    - name: Run Actual Test
      run: |
        echo "=== RUNNING ACTUAL TEST ==="
        bundle exec rails test test/integration/lessons_controller_test.rb:6 || echo "Test failed as expected"
```

### 4. Quick Local Debug Script

For even faster local testing, create a simple script:

```bash
#!/bin/bash
# debug_libraries.sh

echo "=== Quick Library Debug ==="

# Check system libxml2
echo "System libxml2 version:"
pkg-config --modversion libxml-2.0 2>/dev/null || echo "Not found via pkg-config"

# Check Ruby platform
echo "Ruby platform:"
ruby -e "puts Gem::Platform.local"

# Quick Nokogiri check
echo "Nokogiri versions:"
ruby -rnokogiri -e "
puts 'Compiled: ' + Nokogiri::XML::LIBXML_COMPILED_VERSION
puts 'Runtime: ' + Nokogiri::XML::LIBXML_VERSION
puts 'Match: ' + (Nokogiri::XML::LIBXML_VERSION == Nokogiri::XML::LIBXML_COMPILED_VERSION).to_s
"

# Test the failing XPath
echo "XPath test:"
ruby -rnokogiri -e "
begin
  doc = Nokogiri::XML('<test><a href=\"example\">link</a></test>')
  links = doc.xpath('.//*:a | self::*:a')
  puts 'SUCCESS: Found ' + links.length.to_s + ' links'
rescue => e
  puts 'FAILED: ' + e.class.to_s + ': ' + e.message
end
"
```

### 5. One-Commit Debug Strategy

Instead of multiple commits, add all debug code in a single commit with environment variables:

```ruby
# In your test file or application
if ENV['CI_DEBUG']
  # All debug code here
  puts "DEBUG MODE ENABLED"
  
  # Your LibraryInspector code
  # Your test variations
  # Your environment inspection
end

# Your normal application code continues below
```

Then in GitHub Actions:
```yaml
env:
  CI_DEBUG: 'true'
```

This approach lets you:
- **Get comprehensive information in one run**
- **Test different scenarios with workflow inputs** 
- **Avoid polluting your main codebase** with debug code
- **Quickly iterate** on solutions without waiting for full test suites

The key insight is to **gather as much diagnostic information as possible upfront**, rather than making assumptions and testing solutions blindly.

### 6. Advanced Debugging: Custom Rake Tasks

For deeper analysis, create dedicated Rake tasks that can be run both locally and in CI:

```ruby
# lib/tasks/check_nokogiri.rake
namespace :check_nokogiri do
  desc 'Checks Nokogiri, its libxml versions, and potential gem conflicts'
  task versions: :environment do
    puts '--- 🔍 Nokogiri & libxml Check ---'

    unless defined?(Bundler)
      puts '❌ Bundler is not loaded. Please run this task within your bundle context.'
      next
    end

    begin
      require 'nokogiri'
      puts '✅ Nokogiri loaded successfully.'
      puts "\n" + ('-' * 30)

      # Print Nokogiri Version
      puts "💎 Nokogiri Version: #{Nokogiri::VERSION}"
      puts "\n" + ('-' * 30)

      # Explicitly check compiled vs loaded
      compiled_ver = Nokogiri::VERSION_INFO.dig('libxml', 'compiled')
      loaded_ver = Nokogiri::VERSION_INFO.dig('libxml', 'loaded')
      puts '↔️ LibXML Version Comparison:'
      puts "  Compiled: #{compiled_ver}"
      puts "  Loaded:   #{loaded_ver}"
      if compiled_ver == loaded_ver
        puts '  ✅ Versions match (according to Nokogiri).'
      else
        puts '  ⚠️ Mismatch detected! This is likely the source of your warning.'
      end
      puts "\n" + ('-' * 30)

      # Find Nokogiri's location
      nokogiri_spec = Gem.loaded_specs['nokogiri']
      if nokogiri_spec
        puts "📍 Nokogiri Gem Location: #{nokogiri_spec.full_gem_path}"
      else
        puts '❓ Could not find Nokogiri in loaded specs.'
      end
      puts "\n" + ('-' * 30)

      # Check for other gems that might influence libxml
      puts '🔗 Dependency Check:'
      puts '   Looking for gems that depend on Nokogiri or might use libxml...'
      found_potential = false
      Bundler.load.specs.each do |spec|
        is_nokogiri_dep = spec.dependencies.any? { |dep| dep.name == 'nokogiri' }
        is_xml_related = spec.name.include?('xml') && spec.name != 'nokogiri'

        if is_nokogiri_dep
          puts "  -> #{spec.name} (#{spec.version}) depends on Nokogiri."
          found_potential = true
        end
        if is_xml_related
          puts "  -> #{spec.name} (#{spec.version}) might be related (contains 'xml')."
          found_potential = true
        end
      end
      puts '   (If a gem above looks suspicious, investigate its dependencies).'
      unless found_potential
        puts '   No direct Nokogiri dependencies or obvious XML gems found (besides Nokogiri itself).'
      end
    rescue LoadError => e
      puts "❌ Error loading Nokogiri: #{e.message}"
      puts "   Please ensure Nokogiri is in your Gemfile and 'bundle install' has been run."
    end

    puts "\n" + ('-' * 30)
    puts '--- ✅ End of Check ---'
  end

  desc 'Tries to identify gems loading libxml or having C extensions'
  task find_loaders: :environment do
    puts '--- 🔍 Finding Potential libxml Loaders ---'

    unless defined?(Bundler)
      puts '❌ Bundler is not loaded. Please run this task within your bundle context.'
      next
    end

    # Gems known to sometimes interact with libxml or cause C-level issues
    known_suspects = %w[libxml-ruby ox ruby-vips]
    c_extension_gems = []
    xml_related_gems = []

    puts 'Scanning all gems in the bundle...'
    Bundler.load.specs.each do |spec|
      # Check for C extensions
      has_c_ext = !spec.extensions.empty? || 
                   Dir.glob(File.join(spec.full_gem_path, "{lib,ext}/**/*.#{RbConfig::CONFIG['DLEXT']}")).any?

      if has_c_ext && spec.name != 'nokogiri'
        c_extension_gems << "#{spec.name} (#{spec.version})"
      end

      # Check for XML/XSLT related names or known suspects
      if (spec.name.include?('xml') || spec.name.include?('xslt') || 
          spec.name.include?('vips') || known_suspects.include?(spec.name)) && 
          spec.name != 'nokogiri'
        xml_related_gems << "#{spec.name} (#{spec.version})"
      end
    end

    puts "\n" + ('-' * 30)
    puts '--- ⚙️ Gems with C Extensions ---'
    if c_extension_gems.any?
      c_extension_gems.uniq!
      puts '  - ' + c_extension_gems.join("\n  - ")
    else
      puts 'No other gems with C extensions found.'
    end

    puts "\n" + ('-' * 30)
    puts '--- 📄 Potentially Conflicting Gems ---'
    if xml_related_gems.any?
      xml_related_gems.uniq!
      puts '  - ' + xml_related_gems.join("\n  - ")
    else
      puts 'No potentially conflicting gems found.'
    end
  end
end
```

### 7. Production Environment Debugging: Container Deep Dive

When debugging in production-like environments, sometimes you need to get inside the actual container. Here's the workflow for debugging in Kubernetes/GCP environments:

#### Build and Deploy Debug Image

```bash
# Build your image with debug tools included
# Add to your Dockerfile:
# RUN apt-get update && apt-get install -y \
#     ldd strace lsof file \
#     && rm -rf /var/lib/apt/lists/*

# Build and push to your registry
gcloud builds submit --tag gcr.io/your-project/your-app:debug

# Or use Cloud Build
gcloud builds submit --config cloudbuild.yaml
```

#### Interactive Container Debugging

```bash
# Run a temporary container with your production image
kubectl run debug-web \
  --image=gcr.io/your-project/your-app:debug \
  --overrides='{"spec":{"securityContext":{"runAsUser":0,"runAsGroup":0}}}' \
  --namespace=your-namespace \
  --restart=Never \
  --rm -it \
  -- bash

# Now you're inside the production container environment
# Run your debug commands:
bundle exec rake check_nokogiri:versions
bundle exec rake check_nokogiri:find_loaders

# Check system libraries
find /usr -name "*libxml*" 2>/dev/null
dpkg -l | grep libxml
ldd /usr/local/bundle/gems/nokogiri-*/lib/nokogiri/*/nokogiri.so

# Test the actual failure
bundle exec rails runner "
  doc = Nokogiri::XML('<test><a href=\"example\">link</a></test>')
  puts doc.xpath('.//*:a | self::*:a').length
"
```

#### Production-Safe Debug Script

Create a script that can safely run in production without affecting running services:

```ruby
# scripts/production_debug.rb
#!/usr/bin/env ruby

puts "=== PRODUCTION DEBUG SCRIPT ==="
puts "Timestamp: #{Time.now}"
puts "Environment: #{ENV['RAILS_ENV'] || 'development'}"
puts

# Load Rails environment safely
begin
  require_relative '../config/environment'
  puts "✅ Rails environment loaded"
rescue => e
  puts "❌ Failed to load Rails: #{e.message}"
  exit 1
end

# Safe Nokogiri testing
begin
  require 'nokogiri'
  puts "✅ Nokogiri loaded"
  
  compiled = Nokogiri::XML::LIBXML_COMPILED_VERSION
  runtime = Nokogiri::XML::LIBXML_VERSION
  
  puts "Compiled against: #{compiled}"
  puts "Runtime version: #{runtime}"
  puts "Versions match: #{compiled == runtime}"
  
  # Test the problematic XPath
  doc = Nokogiri::XML('<test><a href="example">link</a></test>')
  result = doc.xpath('.//*:a | self::*:a')
  puts "✅ XPath test passed: found #{result.length} elements"
  
rescue Nokogiri::XML::XPath::SyntaxError => e
  puts "❌ XPath syntax error: #{e.message}"
  puts "This confirms the libxml version mismatch issue"
rescue => e
  puts "❌ Unexpected error: #{e.class} - #{e.message}"
end

# Check for conflicting gems
puts "\n=== LOADED GEMS CHECK ==="
%w[ruby-vips image_processing mini_magick rmagick ox libxml-ruby].each do |gem_name|
  if Gem.loaded_specs[gem_name]
    spec = Gem.loaded_specs[gem_name]
    puts "#{gem_name}: #{spec.version} (#{spec.full_gem_path})"
  end
end

puts "\n=== DEBUG COMPLETE ==="
```

#### Kubernetes Debug Workflow

```yaml
# debug-pod.yaml - For persistent debugging sessions
apiVersion: v1
kind: Pod
metadata:
  name: debug-session
  namespace: your-namespace
spec:
  containers:
  - name: debug
    image: gcr.io/your-project/your-app:debug
    command: ["/bin/bash"]
    args: ["-c", "while true; do sleep 30; done"]
    securityContext:
      runAsUser: 0
      runAsGroup: 0
    env:
    - name: RAILS_ENV
      value: "production"
  restartPolicy: Never
```

```bash
# Deploy and use the debug pod
kubectl apply -f debug-pod.yaml
kubectl exec -it debug-session -- bash

# Run your debugging inside the pod
cd /app
bundle exec ruby scripts/production_debug.rb
bundle exec rake check_nokogiri:versions
```

This multi-layered debugging approach gives you:

1. **Quick local feedback** with rake tasks
2. **CI/CD integration** with GitHub Actions
3. **Production environment testing** with Kubernetes
4. **Deep system analysis** with container-level access

The progression from local debugging → CI debugging → production container debugging ensures you can identify issues at each layer of your deployment pipeline.

## Solutions and Workarounds

### 1. Load Order Matters
```ruby
# Load Nokogiri first to establish its libxml2 expectations
require 'nokogiri'
require 'ruby-vips'  # This might still override, but less likely
```

### 2. Force Source Compilation
```bash
# Remove pre-compiled gem and build from source
gem uninstall nokogiri
gem install nokogiri --platform=ruby -- --use-system-libraries=false
```

### 3. Container-Level Solutions

**Use a base image with consistent library versions:**
```dockerfile
FROM ruby:3.4-slim

# Install specific libxml2 version
RUN apt-get update && apt-get install -y \
    libxml2-dev=2.13.8* \
    libxslt1-dev \
    && rm -rf /var/lib/apt/lists/*

# Install gems
COPY Gemfile* ./
RUN bundle install
```

**Set library path precedence:**
```bash
export LD_LIBRARY_PATH="/usr/local/bundle/gems/nokogiri-*/lib:$LD_LIBRARY_PATH"
```

### 4. Application-Level Workarounds

**Detect version mismatch and warn:**
```ruby
class Application < Rails::Application
  config.after_initialize do
    if defined?(Nokogiri)
      runtime = Nokogiri::XML::LIBXML_VERSION
      compiled = Nokogiri::XML::LIBXML_COMPILED_VERSION
      
      if runtime != compiled
        Rails.logger.warn "libxml2 version mismatch: compiled=#{compiled}, runtime=#{runtime}"
      end
    end
  end
end
```

## Prevention Strategies

### 1. Dependency Management
- Pin specific gem versions that are known to work together
- Use `bundle lock --add-platform` for consistent cross-platform builds
- Consider using gems that statically link their dependencies

### 2. Container Best Practices
- Use specific base image tags, not `latest`
- Install system packages with exact versions
- Test in the same environment you deploy to

### 3. Monitoring and Alerting
```ruby
# Add to your application monitoring
def check_library_versions
  return unless defined?(Nokogiri)
  
  runtime = Nokogiri::XML::LIBXML_VERSION
  compiled = Nokogiri::XML::LIBXML_COMPILED_VERSION
  
  if runtime != compiled
    # Alert to your monitoring system
    Metrics.increment('library.version_mismatch', 
                     tags: { gem: 'nokogiri', type: 'libxml2' })
  end
end
```

## Key Takeaways

1. **Pre-compiled gems can have hidden dependencies** that only surface at runtime
2. **Dynamic library conflicts are platform-specific** - what works on macOS might fail on Linux
3. **Load order matters** when multiple gems depend on the same system libraries
4. **LD_DEBUG is your friend** for tracing complex library loading issues
5. **Version mismatches between compile-time and runtime** can cause subtle, hard-to-debug failures

## The Broader Lesson

This debugging journey illustrates a fundamental challenge in modern software development: the complexity of dependency management in containerized, multi-platform applications. The abstraction layers that make development easier (gems, containers, cross-compilation) can also hide important details that surface as mysterious failures in production.

The key is having the right debugging tools and understanding the underlying mechanisms. When high-level abstractions fail, you need to dig into the low-level details of dynamic library loading, symbol resolution, and platform-specific behaviors.

Next time you see a mysterious failure that only happens in certain environments, remember: the answer might be hiding in the dynamic linker's decisions about which version of a library to load.

---

*Have you encountered similar dynamic library conflicts? The debugging techniques in this article apply to many Ruby gems that depend on native libraries. Share your experiences and solutions in the comments below.*
