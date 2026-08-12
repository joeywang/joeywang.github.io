#!/usr/bin/env ruby
# Validates front matter of every post in _posts/.
# Hard-fails on missing title/date; warns on missing description/tags.
# Usage: bundle exec ruby scripts/check_frontmatter.rb [--strict]
#   --strict  also fails on missing description/tags (use once backfill lands)

require "yaml"

STRICT = ARGV.include?("--strict")

posts_dir = File.expand_path("../../_posts", __FILE__)
files = Dir[File.join(posts_dir, "*.md")].sort
errors = []
warnings = []

files.each do |f|
  raw = File.read(f)
  base = File.basename(f)
  m = raw.match(/\A---\s*\n(.*?)\n---\s*\n/m)
  unless m
    errors << "#{base}: no YAML front matter"
    next
  end
  begin
    fm = YAML.safe_load(m[1], permitted_classes: [Date, Time]) || {}
  rescue Psych::Exception => e
    errors << "#{base}: YAML parse error: #{e.message}"
    next
  end
  errors << "#{base}: missing title" if fm["title"].to_s.strip.empty?
  errors << "#{base}: missing date" if fm["date"].nil?
  warnings << "#{base}: missing description" if fm["description"].to_s.strip.empty?
  warnings << "#{base}: missing tags" if fm["tags"].nil?
end

puts "#{files.size} posts checked"

unless warnings.empty?
  puts "\n#{warnings.size} warnings (missing description/tags):"
  puts warnings.first(15).join("\n")
  puts "  ... and #{warnings.size - 15} more" if warnings.size > 15
end

if errors.any?
  puts "\n#{errors.size} errors:"
  puts errors.join("\n")
  exit 1
elsif STRICT && warnings.any?
  puts "\n--strict: #{warnings.size} warnings treated as errors"
  exit 1
end

puts "\nOK"
exit 0
