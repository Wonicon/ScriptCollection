require 'eh.rb'

# CMD: ./one.rb forum user pw gallery-url [dest-dir]

Dir.chdir(ARGV[4]) if ARGV[4]

cookies = login(ARGV[0], ARGV[1], ARGV[2])

puts 'Get signed up'

gallery = Gallery.new
gallery.init_from_known_url(ARGV[3])
gallery.get_page_list(cookies)
gallery.download_pages(cookies)
