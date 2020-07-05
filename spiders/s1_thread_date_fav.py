# 爬取给定帖子列表提取作者、发帖日期、收藏数信息。
# 帖子列表格式：
# line 1. <标题>
# line 2. <url>
# line 3. <空行>
# ...
# 可以通过 SaveTabs 等浏览器拓展收集一系列打开的帖子
# 使用现成 cookie 进行登录，格式为 editThisCookies 等浏览器拓展导出的 cookie jar, 保存为 cookies 文件放在运行路径下。

import requests
from bs4 import BeautifulSoup
import json
import time


def format_cookies(j):
    cookies = {}
    for e in j:
        cookies[e['name']] = e['value']
    return cookies


def thread_loader(filename):
    with open(filename, encoding='utf-8') as f:
        lines = f.readlines()
    result = []  # e = [url, title]
    for i, line in enumerate(lines):
        if i % 3 == 0:
            elem = [line.strip()]
        elif i % 3 == 1:
            elem.append(line.strip())
            result.append(elem)
    result = sorted(result)
    output = []
    for e in result:
        if len(output) == 0 or output[-1] != e:
            output.append(e)
    return output


def parse_s1_html(url, cookies):
    html_doc = requests.get(url, cookies=cookies).text
    soup = BeautifulSoup(html_doc, 'html.parser')
    date = soup.select('div.authi em')[0].text.split(' ')[1]
    fav = soup.select('#favoritenumber')[0].text
    author = soup.select('div.pi > div > a')[0].text
    return date, fav, author


if __name__ == "__main__":
    cookies = format_cookies(json.load(open("cookies", "r")))
    res = thread_loader("threads.txt")

    output = open("output.csv", "w")
    for i, (title, url) in enumerate(res):
        print(title, url)
        date, fav, author = parse_s1_html(url, cookies)
        output.write(",".join([date, title, author, fav, url]) + "\n")
        print(str(i), '/', str(len(res)))
        time.sleep(0.2)
    output.close()
