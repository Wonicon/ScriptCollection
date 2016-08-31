require 'rest_client'
require 'nokogiri'
require 'json'
require 'date'


class Gallery
  # Basic string attributes
  attr_reader :category, :date, :title, :url
  attr_reader :gid, :token
  # A list of string which is the url for each page,
  # with the format <root>/s/<page-token>/<gallery-id>-<page-num>
  attr_reader :page_urls

  # Use the <tr class="gtr[01]"> tag to
  # initialize the gallery object.
  def initialize(row)
    @category = row.children[0].child.child['alt']
    @date = DateTime.parse(row.children[1].text)
    @url = row.children[2].child.children[2].child['href']
    @title = row.children[2].child.children[2].child.child.text
    @gid, @token = @url.split('/')[-2..-1]
    @page_urls = []
  end

  # Parse and extract the page urls from a given html document text.
  # It has the potential danger that hte document isn't corresponding to
  # the gallery itself. But such an interface is suitable for async callback.
  #
  # case return > 0: the number of remaining gallery pages (hold several pages)
  # case return == 0: no need for further request
  def getPageUrls(document)
    isFirst = @page_urls.size == 0
    parsed = Nokogiri::HTML(document)
    @page_urls += parsed.xpath('//a[contains(@href, "/s/")]').map { |a| a['href'] }

    if isFirst
      nav_bar = parsed.xpath('//table[@class="ptt"]/tbody/tr').children
      return nav_bar.size - 3 # including the first one, and '<', '>'.
    else
      return 0
    end
  end

  def downloadSinglePage(page_url, cookies)
    begin
      puts "fetch #{page_url}"
      page = RestClient.get page_url, {:cookies => cookies}
      html = Nokogiri::HTML(page.body)
      img_url = html.xpath('//img[@id="img"]').first['src']
      puts "download #{img_url}"
      img = RestClient.get img_url, {:cookies => cookies}
      puts "downloaded"
      filename = img_url.split('/')[-1]
      filepath = File.join(gid, filename)
      File.open(filepath, 'wb').write(img.body)
    rescue
      puts "download failed"
      sleep 30
      retry
    end
  end

  def downloadPages(cookies)
    puts "Downloading #{@title}"
    page_urls.each_with_index do |page_url, index|
      downloadSinglePage(page_url, cookies)
      puts "#{index + 1}/#{page_urls.size} downloaded"
    end
  end

  private :downloadSinglePage
end


def login(host, username, password)
  form = {
    'act' => 'Login',
    'CODE' => '01',
    'CookieDate' => '1',
    'UserName' => username, 
    'PassWord' => password
  }
  resp = RestClient.post host, form, {
    :content_type => 'application/x-www-form-urlencoded'
  }
  return resp.cookies
end


##
# Get one single page of gallery list
def getGalleriesFrom(url, filter, cookies)
  resp = RestClient.get "#{url}", {
    :params => filter,
    :cookies => cookies
  }
  html = Nokogiri::HTML(resp.body)
  table = html.xpath('//table[@class="itg"]')
  rows = table.xpath('//tr[contains(@class, "gtr")]')
  rows.map { |row| Gallery.new(row) }
end


##
# Get gallery lists after the given due date
def getGalleriesAfter(date, url, filter, cookies)
  galleries = []
  page_num = 0 # page num index from zero
  loop do
    result = getGalleriesFrom("#{url}?page=#{page_num}", filter, cookies)
    after, before = result.partition { |g| g.date > date }
    galleries += after
    puts "Get #{after.size} galleries from page #{page_num + 1} ranging from #{after.first.date} to #{after.last.date}"
    page_num += 1
    break if before.size != 0
  end
  return galleries
end


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
  puts "Get page list for gallery #{gallery.title}"
  document = RestClient.get gallery.url, {:cookies => cookies}
  gallery.getPageUrls(document).times do |page_num|
    page_num += 1 # start from 0, but we need start from 1
    document = RestClient.get "#{gallery.url}?p=#{page_num}", {:cookies => cookies}
    gallery.getPageUrls(document)
  end

  if gallery.page_urls.size == 0
    puts "#{gallery.title} is deprecated?"
  else
    puts "#{gallery.page_urls.size} pages found"
    Dir.mkdir(gallery.gid) if not File.directory?(gallery.gid)
    File.open(File.join(gallery.gid, 'title'), 'w')
        .write(gallery.title)
  end
end

# Download pages
galleries.each do |gallery|
  gallery.downloadPages(cookies)
end
