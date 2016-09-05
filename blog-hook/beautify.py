import sys
from BeautifulSoup import BeautifulSoup as bs

filename = sys.argv[1]

html_file = open(filename, 'r')
html = html_file.read()
html_file.close()

html_prettified = bs(html).prettify()

html_file = open(filename, 'w')
html_file.write(html_prettified)
html_file.close()
