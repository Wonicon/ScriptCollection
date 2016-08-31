#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'fileutils'
require 'nokogiri'
require 'typhoeus'

if ARGV[0] == nil
  puts "Usage: ruby #{__FILE__} tieba.baidu.com/p/xxx"
  exit
end

url = ARGV[0]
uri = URI(url)

# 下载并 parse 帖子
post = Net::HTTP.get(uri)
html = Nokogiri::HTML(post)

# 提取页面信息
title = html.xpath(".//title").text.split('_')[0..-3].join
puts title
FileUtils::mkdir_p(title)
nr_pages = html.xpath(".//*[@id='thread_theme_7']/div[1]/ul/li[2]/span[2]").text.to_i
puts nr_pages
images = html.xpath(".//div[starts-with(@id, 'post_content_')]//img[@class='BDE_Image']").map { |tag| tag.attr('src').split('/').last }

# 下载剩下的页面
if nr_pages > 1
  (nr_pages - 1).times do |i| # start from 2
    url = ARGV[0] + "?pn=#{i + 2}"
    html = Nokogiri::HTML(Net::HTTP.get(URI(url)))
    new =  html.xpath(".//div[starts-with(@id, 'post_content_')]//img[@class='BDE_Image']").map { |tag| tag.attr('src').split('/').last }
    images += new
    puts "Get #{url}, images #{images.size}"
  end
end

hydra = Typhoeus::Hydra.new
images.each_with_index do |img, index|
  puts "Downloading #{img}"
  request = Typhoeus::Request.new("http://imgsrc.baidu.com/forum/pic/item/#{img}")
  request.on_complete do |response|
    puts "Finish #{img}"
    ext = response.headers['Content-Type'].split('/')[-1]
    File.open("#{title}/#{index.to_s.rjust(2, '0')}.#{ext}", 'w').write(response.body)
  end
  hydra.queue(request)
end
hydra.run