#!/usr/bin/env ruby
# file:// exports cannot resolve root-relative CSS. Inline the built stylesheet
# and make public links absolute before Chromium prints the document.
require 'nokogiri'
require 'yaml'
require 'uri'

site_dir, output = ARGV
abort 'Usage: prepare_resume_print.rb SITE_DIR OUTPUT' unless site_dir && output
config = YAML.load_file(File.expand_path('../_config.yml', __dir__))
doc = Nokogiri::HTML(File.read(File.join(site_dir, 'resume.html')))
stylesheets = doc.css('link[rel="stylesheet"]')
abort 'Expected one self-contained résumé stylesheet' unless stylesheets.length == 1
stylesheet = stylesheets.first
href = stylesheet['href']
expected = "#{config.fetch('baseurl', '')}/assets/css/resume_custom.css"
abort "Unexpected résumé stylesheet: #{href}" unless href == expected
style = Nokogiri::XML::Node.new('style', doc)
style.content = File.read(File.join(site_dir, 'assets/css/resume_custom.css'))
stylesheet.replace(style)
origin = config.fetch('url')
doc.css('a[href]').each do |link|
  link['href'] = URI.join(origin, link['href']).to_s if link['href'].start_with?('/')
end
File.write(output, doc.to_html)
