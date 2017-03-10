# Remove the unexpected newline in html code between two Chinese characters
# TODO Current implementation doesn't take <pre> tag into consideration.
#      However, writing Chinese inside a <pre> tag is quite a rare case.

Dir["#{ARGV[0]}/**.html"].each do |html|
  text = File.read(html).gsub(/(?<=[^\p{ASCII}])\n *(?=[^a-zA-Z])/, '')
  File.write(html, text)
end
