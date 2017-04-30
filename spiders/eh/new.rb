require './eh.rb'

# CMD: ./new.rb site forum user pw oldest-date [dest-dir]

Dir.chdir(ARGV[5]) if ARGV[5]

cookies = login(ARGV[1], ARGV[2], ARGV[3])

puts 'Get signed up'

filter = {
  'f_doujinshi' => 1,
  'f_manga'     => 1,
  'f_artistcg'  => 1,
  'f_search'    => 'language:chinese$',
  'f_apply'     => 'Apply+Filter'
}

due_date = Date.parse(ARGV[4])

galleries = getGalleriesAfter(due_date, ARGV[0], filter, cookies)

puts "Get #{galleries.size} galleries in total"

# Get page list
galleries.each do |gallery|
  gallery.getPageList(cookies)
  gallery.downloadPages(cookies)
end
