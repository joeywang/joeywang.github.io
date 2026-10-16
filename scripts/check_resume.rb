#!/usr/bin/env ruby
# Run after jekyll build: bundle exec ruby scripts/check_resume.rb PATH_TO_SITE
require 'nokogiri'
require 'yaml'
require 'uri'
require 'tmpdir'
require 'rbconfig'

site = File.expand_path(ARGV.fetch(0, '_site'))
root = File.expand_path('..', __dir__)
cv = YAML.load_file(File.join(root, '_data/cv_data.yml'))
doc = Nokogiri::HTML(File.read(File.join(site, 'resume.html')))
raise 'Missing name or focus' unless doc.text.include?(cv.fetch('name')) && doc.text.include?('Applied AI')
cv.fetch('experience').each do |job|
  entry = doc.at_css("article##{job.fetch('id')}")
  raise "Missing experience: #{job['company']}" unless entry && entry.text.include?(job['company'])
  raise 'Experience must not be hidden' if entry['style'].to_s.include?('none') || entry.key?('hidden')
  job.fetch('details').each { |detail| raise 'Missing experience detail' unless entry.text.include?(detail) }
end
raise 'Unexpected rating or script dependency' unless doc.css('canvas, script, [role="meter"]').empty?
project_links = doc.css('#projects a')
raise 'Missing AI evidence links' unless project_links.length == cv.fetch('projects').count { |p| p['post'] }
['resume.html', 'about/index.html', 'index.html'].each do |page|
  page_doc = Nokogiri::HTML(File.read(File.join(site, page)))
  selector = page == 'about/index.html' ? 'main #core-wrapper' : (page == 'index.html' ? '.home-intro' : 'body')
  # Chirpy versions differ in their main container; check the About article itself.
  scope = page_doc.at_css(selector) || page_doc.at_css('main')
  raise "Missing page scope: #{page}" unless scope
  scope.css('a[href]').each do |link|
    href = link['href']
    next unless href.start_with?('/')
    path = File.join(site, URI::DEFAULT_PARSER.unescape(href.split(/[?#]/).first).sub(%r{\A/}, ''))
    raise "Broken local link: #{href}" unless File.file?(path) || File.file?(File.join(path, 'index.html'))
  end
end
Dir.mktmpdir('resume-print-', ENV.fetch('TMPDIR', '/mnt/data/.hermes/cache/scratch')) do |dir|
  output = File.join(dir, 'print.html')
  ok = system(RbConfig.ruby, File.join(__dir__, 'prepare_resume_print.rb'), site, output)
  raise 'Print preparation failed' unless ok
  print_doc = Nokogiri::HTML(File.read(output))
  raise 'Print stylesheet must be inline' unless print_doc.css('link[rel="stylesheet"]').empty? && print_doc.at_css('style').text.include?('@media print')
  print_doc.css('a[href]').each { |a| raise 'Relative link in PDF' if a['href'].start_with?('/') }
end
puts "Résumé checks passed: #{cv.fetch('experience').length} visible roles, #{project_links.length} evidence links, local links, script-free skills, self-contained print CSS."
