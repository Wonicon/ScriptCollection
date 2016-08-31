# Usage:
#   ruby course.rb <stu-id> <password> [category] [campus] [host]
# 
# Rerequsities:
#   # apt-get install ruby
#   $ gem install rest-client
#   $ gem install nokogiri
#
# Note:
#   if a file called 'wishes' exists, then we only scout the wished
#   courses, otherwise we try to enroll as many courses as we can (up to 3).
#   In wishes, each line is the course name found in the site.

require 'rest_client'
require 'nokogiri'
require 'set'

class Course
  def initialize(tr)
    @tr = tr
  end

  def name
    @tr.children[2].text
  end

  def time
    @tr.children[4].text
  end

  def selection
    @tr.children[9].child
  end

  def id
    selection.attributes['value']
  end

  def available?
    selection != NIL
  end
end


class EduAdmin # a.k.a jiaowu
  def initialize(host, category, campus)
    @host   = host
    @campus = campus
    method_name = {
      '通识课' => 'discuss', 
      '公选课' => 'public'
    }
    @count = 0
    @category = method_name[category]
    @wishes = Set.new

    wishes = 'wishes'
    if File.exist?(wishes)
      File.open(wishes).readlines.each do |line|
        @wishes << line
        puts "scout #{line}"
      end
    end
  end

  def login(username, password)
    params = {
      'userName' => username,
      'password' => password,
      'returnUrl' => 'null'
    }
    action = '/login.do'
    resp = RestClient.get(@host + action, {:params => params})
    @cookies = resp.cookies
  end

  def available_courses
    action = '/student/elective/courseList.do'

    params = {
      'method' => "#{@category}RenewCourseList",
      'campus' => @campus
    }

    resp = RestClient.get(@host + action, {:params => params, :cookies => @cookies})
    
    html = Nokogiri::HTML(resp.body)

    html.xpath("//tr[contains(@class, 'TABLE_TR_')]")
        .map { |tr| Course.new(tr) }
        .select { |course| course.available? and (@wishes.empty? or @wishes.include?(course.name)) }
  end

  def enroll(course)
    if @count == 3
      return
    end

    puts "enroll #{course.name}"
    action = '/student/elective/courseList.do'
    params = {
      'method' => "submit#{@category.capitalize}Renew",
      'classId' => course.id,
      'campus' => @campus
    }
    resp = RestClient.get(@host + action, {:params => params, :cookies => @cookies})
    collision_msg = '和已选课程存在时间冲突，无法选中！'
    if resp.body.include? collision_msg
      puts collision_msg
    else
      @count += 1
    end
  end
end


username = ARGV[0]
password = ARGV[1]
category = ARGV[2] || '公选课'
campus   = ARGV[3] || '仙林校区'
host     = ARGV[4] || 'http://jwas2.nju.edu.cn:8080/jiaowu'

admin = EduAdmin.new(host, category, campus)

puts "sign in as #{username}"

admin.login(username, password)

puts "get available #{category} at #{campus} from #{host}"

admin.available_courses.each { |course| admin.enroll(course) }