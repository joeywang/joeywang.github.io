#!/usr/bin/env ruby
# Backfills missing `description` front matter from each post's first paragraph.
# Also reports candidate tags for posts missing tags (no auto-write for tags).
#
# Usage: bundle exec ruby scripts/backfill_frontmatter.rb [--apply] [--limit N]
#   (default)  dry run: prints summary + samples, writes nothing
#   --apply    writes the description lines into post files
#   --limit N  only process the first N files (dry run useful for spot checks)

require "yaml"

APPLY = ARGV.include?("--apply")
LIMIT = (ARGV.find { |a| a.start_with?("--limit=") } || "").split("=")[1]&.to_i

posts_dir = File.expand_path("../../_posts", __FILE__)
files = Dir[File.join(posts_dir, "*.md")].sort
files = files.first(LIMIT) if LIMIT

STOPWORDS = %w[the a an and or but of in on for with to from as by at be is are was were
               you your we our i my me it its this that these those how why what when where
               using use used using user users new make makes making get getting guide post
               ruby rails].freeze

def yaml_escape(str)
  %("#{str.gsub("\\", "\\\\").gsub('"', '\\"')}")
end

# First usable paragraph: skips headings, code fences, HTML embeds, lists,
# images, and markdown-injected scaffolding text.
def extract_description(raw)
  body = raw.sub(/\A---\s*\n.*?\n---\s*\n/m, "")
  para = []
  body.lines.map(&:strip).each do |line|
    next if line.empty? && para.empty?
    break if line.empty? && !para.empty?
    next if line.start_with?("#", "```", "|", ">", "-", "*", "![", "<")
    next if line.include?("Your browser does not support")   # <audio> fallback text
    next if line.match?(/以下是关于|The following is a markdown/i)  # AI-import scaffolding
    next if line.match?(/\A\d+[.)]/)
    para << line
    break if para.length >= 2
  end
  return nil if para.empty?
  text = para.join(" ")
  text = text.gsub(/<[^>]+>/, " ")                       # HTML tags (audio embeds etc.)
            .gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')          # markdown links -> text
            .gsub(/`([^`]+)`/, '\1')                      # inline code -> text
            .gsub(/[*_~]{1,2}/, "")                       # emphasis markers
            .gsub(/\s+/, " ").strip
  return nil if text.empty?
  text = text[0, 160]
  text = text[0, text.rindex(/\s/) || text.length] if text.length == 160
  text
end

def suggest_tags(raw)
  body = raw.sub(/\A---\s*\n.*?\n---\s*\n/m, "")
  words = body.downcase.scan(/[a-z][a-z0-9]{3,}/)
  freq = words.each_with_object(Hash.new(0)) { |w, h| h[w] += 1 }
  freq.reject { |w, _| STOPWORDS.include?(w) || w.length > 20 }
      .sort_by { |_, c| -c }.first(5).map(&:first)
end

def front_matter(f)
  m = File.read(f).match(/\A---\s*\n(.*?)\n---\s*\n/m)
  return {} unless m
  YAML.safe_load(m[1], permitted_classes: [Date, Time]) || {}
rescue Psych::Exception
  {}
end

changed = 0
skipped_no_text = 0
samples = []
files.each do |f|
  base = File.basename(f)
  fm = front_matter(f)
  next unless fm["description"].to_s.strip.empty?

  desc = extract_description(File.read(f))
  if desc.nil?
    skipped_no_text += 1
    next
  end

  raw = File.read(f)
  title_line = raw[/^title:.*$/]
  next unless title_line

  desc_line = "description: #{yaml_escape(desc)}"
  File.write(f, raw.sub(title_line, "#{title_line}\n#{desc_line}")) if APPLY
  changed += 1
  samples << "  #{base}\n    -> #{desc}" if samples.length < 5
end

missing_tags = files.count { |f| front_matter(f)["tags"].nil? }

puts "#{files.size} posts scanned, #{changed} missing description#{APPLY ? ' FIXED' : ' (dry run — add --apply to write)'}, #{skipped_no_text} skipped (no extractable text)"
puts samples.join("\n") unless samples.empty?
puts "\n#{missing_tags} posts still missing tags (auto-tags risky; review candidates manually)"
exit 0
