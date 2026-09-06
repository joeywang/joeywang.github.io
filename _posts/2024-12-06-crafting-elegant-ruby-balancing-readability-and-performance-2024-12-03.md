---
layout: post
title: "Ruby readability vs performance: filter_map and a single loop"
description: "Ruby's filter_map cuts a multi-pass select/map/uniq chain to one pass, and a plain each loop goes further still when performance actually matters."
date: 2024-12-06 23:35 +0000
categories: [Engineering]
tags: [ruby, performance]
---
<audio controls preload="metadata" src="/assets/audio/crafting-elegant-ruby-balancing-readability-and-performance-2024-12-03-summary.ogg">
  Your browser does not support the audio element.
</audio>

A sorting problem that started clean turned out to be doing more work than it needed to. The initial pass looked fine on the page:

```ruby
starts = commands.select { |command| command.type == 'start' }.map(&:interaction).uniq
selected = commands.select { |command| command.type == 'select' }.map(&:interaction).uniq
completes = commands.select { |command| command.type == 'complete' }.map(&:interaction).uniq
```

Three separate passes over the same `commands` collection, each one filtering, then mapping, then deduplicating. Readable, but the collection gets walked nine times total for what should be three lookups.

## One method, one pass

Ruby 2.7's `filter_map` collapses `select` and `map` into a single pass:

```ruby
starts = commands
  .filter_map { |command| command.interaction if command.type == 'start' }
  .uniq

selected = commands
  .filter_map { |command| command.interaction if command.type == 'select' }
  .uniq

completes = commands
  .filter_map { |command| command.interaction if command.type == 'complete' }
  .uniq
```

Same result, fewer intermediate arrays, and it reads about as clearly as the original.

## When you need the extra pass gone too

`filter_map` still walks `commands` three separate times, once per variable. If that collection is large and this runs often, a single `each` with a `case` gets it down to one pass total:

```ruby
starts = []
selected = []
completes = []

commands.each do |command|
  case command.type
  when 'start'
    starts << command.interaction
  when 'select'
    selected << command.interaction
  when 'complete'
    completes << command.interaction
  end
end

starts.uniq!
selected.uniq!
completes.uniq!
```

It's less immediately legible than the `filter_map` version, three names accumulating inside one loop body instead of three self-contained expressions, but it's the version to reach for once profiling actually shows the multi-pass version costing something.

## The order to reach for these in

Start with the `select`/`map` chain or the `filter_map` version. Both describe what the code does without making the reader trace a loop body. Move to the manual `each` loop only when you have a specific, measured reason: profiling data, a collection large enough that three passes versus one is visible, or a hot path that runs on every request. Optimizing before you have that reason usually just trades readability for a speedup nobody will notice.
