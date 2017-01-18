require 'rest_client'
require 'nokogiri'
require 'json'
require 'date'


class Gallery
  # Basic string attributes
  attr_reader :title, :date, :url
  attr_reader :gid, :token
  # A list of string which is the url for each page,
  # with the format <root>/s/<page-token>/<gallery-id>-<page-num>
  attr_reader :page_urls

  # Use the <tr class="gtr[01]"> tag to
  # initialize the gallery object.
  def initialize()
    @page_urls = []
  end

  def initByKnownURL(url)
    @title = nil
    @date = nil
    @url = url
    @gid, @token = @url.split('/')[-2..-1]
  end

  def initByElement(element)
    @title = row.children[2].child.children[2].child.child.text
    @date = DateTime.parse(row.children[1].text)
    @url = row.children[2].child.children[2].child['href']
    @gid, @token = @url.split('/')[-2..-1]
  end

  # Parse and extract the page urls from a given html document text.
  # It has the potential danger that the document isn't corresponding to
  # the gallery itself. But such an interface is suitable for async callback.
  #
  # case return > 0: the number of remaining gallery pages (hold several pages)
  # case return == 0: no need for further request
  def getPageUrls(document)
    isFirst = @page_urls.size == 0
    parsed = Nokogiri::HTML(document)
    @page_urls += parsed.xpath('//a[contains(@href, "/s/")]').map { |a| a['href'] }

    if isFirst
      pages = parsed.xpath('//table[@class="ptt"]/tr').children[-2].children[0].xpath('text()').to_s.to_i
      return pages - 1
    else
      return 0
    end
  end

  ##
  # One preview page contains several single pages.
  # We will iterate on the preview page number to get all single pages' url.
  def getPageList(cookies)
    puts @url

    document = RestClient.get @url, {:cookies => cookies}

    if @title == nil
      @title = (Nokogiri::HTML(document)).xpath("//h1[@id='gj']").xpath('text()')
      document = RestClient.get @url, {:cookies => cookies}
    end

    puts "Get page list for gallery #{@title}"
    puts "Parse the first preview page list"
    getPageUrls(document).times do |page_num|
      page_num += 1 # start from 0, but we need start from 1
      puts "Fetch the #{page_num}th page list"
      document = RestClient.get "#{@url}?p=#{page_num}", {:cookies => cookies}
      getPageUrls(document)
    end

    if @page_urls.size == 0
      puts "#{@title} is deprecated?"
    else
      puts "#{@page_urls.size} pages found"
      path = "#{@gid}_#{@title}"
      Dir.mkdir(path) if not File.directory?(path)
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
      path = "#{@gid}_#{@title}"
      filepath = File.join(path, filename)
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
