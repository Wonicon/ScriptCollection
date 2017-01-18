require './eh.rb'

cookies = login(ARGV[4], ARGV[1], ARGV[2])

puts "Get signed up"

filter = {
  'f_doujinshi' => 1,
  'f_manga'     => 1,
  'f_artistcg'  => 1,
  'f_search'    => 'language:chinese$',
  'f_apply'     => 'Apply+Filter'
}

due_date = Date::parse(ARGV[3])

galleries = getGalleriesAfter(due_date, ARGV[0], filter, cookies)

puts "Get #{galleries.size} galleries in total"

# Get page list
galleries.each do |gallery|
  gallery.getPageList(cookies)
end

# Download pages
galleries.each do |gallery|
  gallery.downloadPages(cookies)
end
