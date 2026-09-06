---
layout: post
title: "Nokogiri vs libxml2: Debugging a Dynamic Library Conflict"
description: "Why Nokogiri XPath queries failed in Docker but not on an M1 Mac: a libxml2 version mismatch caused by indirect dynamic library loading in Ruby."
date: "2025-04-22"
categories: [Engineering]
tags: [ruby, debugging, docker, linux]
---

<audio controls preload="metadata" src="/assets/audio/nokogiri-load-problem-summary.ogg">
  Your browser does not support the audio element.
</audio>

## Tests pass locally, fail in the container

Rails tests passed on an M1 MacBook and failed in Docker with a cryptic XPath error:

```
Nokogiri::XML::XPath::SyntaxError: ERROR: Invalid expression: .//*:a | self::*:a
```

The expression is valid XPath. Something else was wrong.

## The warning that explains it

Buried in the logs:

```
WARNING: Nokogiri was built against libxml version 2.13.8, but has dynamically loaded 2.9.14
```

Nokogiri was compiled against one libxml2 version and running against another at runtime. The XPath syntax used in 2.13.8 doesn't exist in 2.9.14.

## How Ruby loads native extensions

`require 'nokogiri'` triggers a chain: Ruby finds the extension on `$LOAD_PATH`, calls `dlopen()` to load the shared library, the dynamic linker resolves its C dependencies, and function calls get bound to whatever got loaded. The bug lives in that third step: the dynamic linker can resolve to a different libxml2 than the one Nokogiri expects.

## Tracing it

Platform gave the first clue:

```bash
# M1 Mac
$ ruby -e 'puts Gem::Platform.local.to_s'
arm64-darwin-24

# Linux container
$ ruby -e 'puts Gem::Platform.local.to_s'
x86_64-linux-gnu
```

Different platforms, different pre-compiled gems, different linking strategies. `ldd` on the compiled extension showed no direct libxml2 dependency at all:

```bash
$ ldd ./lib/nokogiri/3.4/nokogiri.so
linux-vdso.so.1 (0x00007ffe8ed31000)
libm.so.6 => /lib/x86_64-linux-gnu/libm.so.6 (...)
libdl.so.2 => /lib/x86_64-linux-gnu/libdl.so.2 (...)
libpthread.so.0 => /lib/x86_64-linux-gnu/libpthread.so.0 (...)
libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (...)
/lib64/ld-linux-x86-64.so.2 (...)
```

Either it's statically linked, or it's being resolved indirectly. `LD_DEBUG` confirmed the latter:

```bash
$ LD_DEBUG=libs ruby -rnokogiri -e "puts 'loaded'" 2>&1 | grep libxml2
file=/lib/x86_64-linux-gnu/libxml2.so.2 [0]; needed by nokogiri.so [0] (relocation dependency)
```

A relocation dependency: Nokogiri doesn't link libxml2 directly, it needs it resolved at runtime through whatever already loaded it. The full chain:

```
ruby-vips  ─▶ system vips ─▶ libxml2 v2.9.14
                                  │
nokogiri (built for v2.13.8) ────▶ bound to v2.9.14 instead (wrong)
```

`ruby-vips` loads first and pulls in the system's `libxml2.so.2` (2.9.14). Nokogiri loads after and finds libxml2 symbols already resolved to that version, so its calls bind to 2.9.14 instead of the 2.13.8 it was built against. XPath syntax compiled for 2.13.8 then fails at runtime.

## Tools worth knowing for this class of bug

```bash
# Trace all library loading
LD_DEBUG=libs,files ruby -rnokogiri -e "puts 'loaded'" 2>&1 | grep xml

# See what's actually loaded at runtime
lsof -p $(pgrep ruby) | grep libxml

# Check symbol resolution
LD_DEBUG=symbols ruby -rnokogiri -e "Nokogiri::XML('<test/>')" 2>&1 | grep xml

# Inspect a gem's compiled extensions
find $(gem which nokogiri | xargs dirname) -name "*.so" -exec ldd {} \;
```

And from inside Ruby:

```ruby
require 'nokogiri'
puts "Runtime version: #{Nokogiri::XML::LIBXML_VERSION}"
puts "Compiled version: #{Nokogiri::XML::LIBXML_COMPILED_VERSION}"
puts Nokogiri::VERSION_INFO.to_yaml
```

## Debugging this in CI without endless commit cycles

The trap with a bug like this is iterating by pushing a commit, waiting for CI, reading one more log line, and repeating. Gather everything in one run instead: gate a diagnostic block behind an env var so it's easy to enable and never runs in normal operation.

```ruby
# lib/tasks/check_nokogiri.rake
namespace :check_nokogiri do
  desc "Compares Nokogiri's compiled vs loaded libxml version and flags conflicting gems"
  task versions: :environment do
    require 'nokogiri'
    compiled = Nokogiri::VERSION_INFO.dig('libxml', 'compiled')
    loaded   = Nokogiri::VERSION_INFO.dig('libxml', 'loaded')
    puts "Compiled: #{compiled}  Loaded: #{loaded}  Match: #{compiled == loaded}"

    Bundler.load.specs.each do |spec|
      next unless spec.name.include?('xml') || spec.name.include?('vips')
      next if spec.name == 'nokogiri'
      puts "Potentially conflicting gem: #{spec.name} (#{spec.version})"
    end
  end
end
```

Run it locally, in CI with `LD_DEBUG=files,libs` set, and inside the actual production container if the environments diverge:

```bash
kubectl run debug-web --image=gcr.io/your-project/your-app:debug \
  --namespace=your-namespace --restart=Never --rm -it -- bash
# then, inside the pod:
bundle exec rake check_nokogiri:versions
ldd /usr/local/bundle/gems/nokogiri-*/lib/nokogiri/*/nokogiri.so
```

One run in each environment tells you more than five commits of trial and error.

## Fixes

**Load order.** Requiring Nokogiri before the gem that pulls in the conflicting system library reduces the chance of the wrong binding, though it's not guaranteed:

```ruby
require 'nokogiri'
require 'ruby-vips'
```

**Force source compilation** instead of using the pre-built binary gem:

```bash
gem uninstall nokogiri
gem install nokogiri --platform=ruby -- --use-system-libraries=false
```

**Pin the system library version** in the container image so there's only one libxml2 to resolve to:

```dockerfile
FROM ruby:3.4-slim
RUN apt-get update && apt-get install -y \
    libxml2-dev=2.13.8* \
    libxslt1-dev \
    && rm -rf /var/lib/apt/lists/*
COPY Gemfile* ./
RUN bundle install
```

**Detect and warn at boot**, so a mismatch shows up in logs immediately instead of as a mysterious test failure weeks later:

```ruby
class Application < Rails::Application
  config.after_initialize do
    if defined?(Nokogiri) && Nokogiri::XML::LIBXML_VERSION != Nokogiri::XML::LIBXML_COMPILED_VERSION
      Rails.logger.warn "libxml2 version mismatch: compiled=#{Nokogiri::XML::LIBXML_COMPILED_VERSION}, runtime=#{Nokogiri::XML::LIBXML_VERSION}"
    end
  end
end
```

## The lesson

Pre-compiled gems carry hidden dependencies that only surface at runtime, and they surface differently per platform: what resolves cleanly on macOS can break on Linux because the two use different pre-built binaries and different system libraries. Load order matters whenever two gems touch the same system library. And `LD_DEBUG` is the tool that turns "mysterious failure in one environment" into a one-line diagnosis, because it shows you what the dynamic linker actually decided, not what you assumed it would.
