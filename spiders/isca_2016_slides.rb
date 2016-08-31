#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'fileutils'
require 'nokogiri'
require 'typhoeus'

class Slide
  attr_reader :name, :url
  def initialize(name, url)
    @name = name
    @url = url
  end
end

slides = []

child_text = '[slides]'
skipped_tail_len = child_text.length

uri = URI('http://isca2016.eecs.umich.edu/index.php/main-program/')

# 下载并 parse 网页
post = Net::HTTP.get(uri)
html = Nokogiri::HTML(post)

puts "Downloaded #{uri}"

# 提取页面信息
html.xpath("//a[text()='#{child_text}']").each do |tag|
	name = tag.parent.text[0...-skipped_tail_len]
  url = tag.attr('href')
  slides << Slide.new(name, url)
end

# 下载剩下的页面
hydra = Typhoeus::Hydra.new
slides.each do |slide|
  puts "Downloading #{slide.name}"
  request = Typhoeus::Request.new(slide.url)
  request.on_complete do |response|
    puts "Finish #{slide.name}"
    File.open("#{slide.name}#{File.extname(slide.url)}", 'w').write(response.body)
  end
  hydra.queue(request)
end

hydra.run