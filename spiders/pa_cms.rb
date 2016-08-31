#!/usr/bin/env ruby
# 爬课程管理系统，获得所有提交PA的学生学号
require 'net/http'
require 'uri'
require 'nokogiri'

if ARGV.length != 2
    puts "Usage: proc username password"
    exit
end

pa_id = {
    "pa0" => 351,
    "pa1_1" => 352,
    "pa1_2" => 353,
    "pa1_fin" => 354,
    "pa2_1" => 37,
    "pa2_2" => 38,
    "pa2_3" => 62,
    "pa2_4" => 63,
    "pa2_fin" => 64,
    "pa3_1" => 560,
    "pa3_2" => 561,
    "pa3_3" => 562,
    "pa3_fin" => 91,
    "pa4_1" => 100,
    "pa4_2" => 101,
    "pa4_fin" => 102
}

url = "cslabcms.nju.edu.cn"
host = "http://#{url}/cms"
Net::HTTP.start(url, 80) do |http|
    # Log in
    puts "Log in as #{ARGV[0]}"

    post = Net::HTTP::Post.new(URI("#{host}/login/index.php"))

    post.set_form_data(
        "username" => ARGV[0],
        "password" => ARGV[1],
        "rememberusername" => "1"
    )

    response = http.request(post)

    # They use cookie to check log-in
    puts("Filtering cookie")

    is_1st_MS = true
    is_1st_ID = true
    cookies = ""
    cookie_list = response['Set-Cookie'].split
    cookie_list.each do |entry|
        if entry.include?('MoodleSession')
            if is_1st_MS
                is_1st_MS = false
            else
                cookies = cookies + entry
            end
        elsif entry.include?('MOODLEID1_')
            if is_1st_ID
                is_1st_ID = false
            else
                cookies = cookies + entry
            end
        end
    end

    # Settings

    puts "Get session information"

    info = Net::HTTP::Get.new(URI("#{host}/mod/assign/view.php?id=#{pa_id['pa0']}&action=grading"))
    info['Cookie'] = cookies
    response = http.request(info)
    puts response.msg
    html = Nokogiri::HTML(response.body)
    sesskey = html.xpath('//input[@name="sesskey"]/@value')[0]
    contextid = html.xpath('//input[@name="contextid"]/@value')[0]

    puts "Set to get all submissions in one page"

    post = Net::HTTP::Post.new(URI("#{host}/mod/assign/view.php"))
    post.set_form_data(
        "contextid" => "#{contextid}",
        "id" => "#{pa_id['pa0']}",
        "sesskey" => "#{sesskey}",
        "action" => "saveoptions",
        "_qf__mod_assign_grading_options_form" => "1",
        "mform_isexpanded_id_general" => "1",
        "perpage" => "-1",
        "filter" => "submitted")
    post['Cookie'] = cookies

    response = http.request(post)

    puts response.msg

    pa_id.each do |pa, id|
        puts "Downloading #{pa}"
        uri = URI("#{host}/mod/assign/view.php?id=#{id}&action=grading")
        get = Net::HTTP::Get.new(uri)
        get['Cookie'] = cookies
        page = http.request(get)
        puts page.msg

        puts "Parsing html"
        html = Nokogiri::HTML(page.body)
        puts "Searching stu-id"
        stu_id = []
        html.xpath('//td[@class="cell c3 idnumber"]').each do |td|
            stu_id.push(td.content)
        end

        puts "Writing back results"
        open("#{pa}.txt", "w") do |f|
            stu_id.sort.each do |id|
                f.puts(id)
            end
        end

    end
end