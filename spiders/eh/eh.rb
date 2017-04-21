require 'rest_client'
require 'parallel'
require 'nokogiri'
require 'date'


$jobs = 4


class GalleryPage
  attr_reader :page_urls

  def initialize(cookies, url)
    puts "Download preview page #{url}"
    html = RestClient.get(url, {:cookies => cookies})
    @document = Nokogiri::HTML(html)
    @page_urls = @document.xpath('//a[contains(@href, "/s/")]').map { |a| a['href'] }
  end
end


class GalleryIndex < GalleryPage
  attr_reader :page_num

  def initialize(cookies, url)
    super(cookies, url)
    @page_num = @document.xpath('//table[@class="ptt"]/tr').children[-2].children[0].xpath('text()').to_s.to_i
  end

  def title
    @document.xpath("//h1[@id='gj']").xpath('text()')
  end
end


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
    @path = '.'
  end

  def initByKnownURL(url)
    @title = nil
    @date = nil
    @url = url
    @gid, @token = @url.split('/')[-2..-1]
  end

  def initByElement(element)
    @title = element.children[2].child.children[2].child.child.text
    @date = DateTime.parse(element.children[1].text)
    @url = element.children[2].child.children[2].child['href']
    @gid, @token = @url.split('/')[-2..-1]
  end

  ##
  # One preview page contains several single pages.
  # We will iterate on the preview page number to get all single pages' url.
  def getPageList(cookies)
    first_page = GalleryIndex.new(cookies, @url)
    @title = first_page.title if @title == nil
    puts "Get page list for gallery #{@title}"

    puts "This gallery has #{first_page.page_num} preview pages"

    # Get the page urls from the first preview page.
    # As we have already got the html text, we have no need to download it again.
    @page_urls += first_page.page_urls
    # Get the page urls from the rest preview pages.
    # As each preview page contains several pages, it will result in a nested array,
    # so we need to flatten it at last.
    @page_urls += Parallel.map((1...first_page.page_num).to_a) do |preview_page_index|
      puts "Fetch the #{preview_page_index + 1}th preview page"
      preview_page = GalleryPage.new(cookies, "#{@url}?p=#{preview_page_index}")
      preview_page.page_urls
    end
    @page_urls = @page_urls.flatten

    if @page_urls.size == 0
      puts "#{@title} is deprecated?"
    else
      puts "#{@page_urls.size} pages found"
      @path = "#{@gid}_#{@title}".gsub(/\//, '_')  # Avoid invalid '/' in title.
      Dir.mkdir(@path) if not File.directory?(@path)
    end

    puts "Page urls are as follows:"
    puts @page_urls
  end

  def downloadSinglePage(page_url, cookies)
    begin
      begin
        puts "Fetch #{page_url}"
        page = RestClient.get page_url, {:cookies => cookies}
      rescue
        puts "Failed to fetch #{page_urls}"
        raise
      end

      html = Nokogiri::HTML(page.body)
      img_url = html.xpath('//img[@id="img"]').first['src']
      alt = html.xpath('//*[@id="loadfail"]').first['onclick'][/'(.*)'/, 1]
      alt_url = "#{page_url}?nl=#{alt}"

      begin
        puts "Download #{img_url}"
        img = RestClient.get img_url, {:cookies => cookies}
      rescue
        puts "Failed to download #{filename}"
        page_url = alt_url
        raise
      end

      filename = img_url.split('/')[-1]
      filepath = File.join(@path, filename)
      puts "#{filename} downloaded"
      File.open(filepath, 'wb').write(img.body)
    rescue
      sleep 10
      retry
    end
  end

  def downloadPages(cookies)
    puts "Downloading #{@title}"
    if Dir[File.join(@paht, '*')].size == @page_urls.size
      puts "This gallery has bee finished"
      return
    end

    Parallel.each_with_index(@page_urls, :in_processors => $jobs) do |page_url, index|
      downloadSinglePage(page_url, cookies)
      puts "#{Dir[File.join(@path, '*')].size}/#{@page_urls.size} downloaded"
    end
  end

  # private :downloadSinglePage
end


##
# Login the <host> site with <username> and <password>.
# Return the responsed cookies, as authentication used by other parts.
def login(host, username, password)
  form = {
    'act' => 'Login',
    'CODE' => '01',
    'CookieDate' => '1',
    'UserName' => username, 
    'PassWord' => password
  }
  # Make the post recognized as a form submitted.
  headers = { :content_type => 'application/x-www-form-urlencoded' }
  resp = RestClient.post(host, form, headers)
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
  rows.map do |row|
    gallery = Gallery.new
    gallery.initByElement(row)
    gallery
  end
end


##
# Get gallery lists after the given due date
def getGalleriesAfter(date, url, filter, cookies)
  galleries = []
  page_num = 0 # page num index from zero
  loop do
    puts url
    result = getGalleriesFrom("#{url}?page=#{page_num}", filter, cookies)
    after, before = result.partition { |g| g.date > date }
    galleries += after
    puts "Get #{after.size} galleries from page #{page_num + 1} ranging from #{after.first.date} to #{after.last.date}"
    page_num += 1
    break if before.size != 0
  end
  return galleries
end
