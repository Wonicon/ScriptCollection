require './eh.rb'

# CMD: ./one.rb url user pw forum

cookies = login(ARGV[3], ARGV[1], ARGV[2])
puts cookies
puts "Get signed up"

gallery = Gallery.new
gallery.initByKnownURL(ARGV[0])
gallery.getPageList(cookies)
gallery.downloadPages(cookies)
