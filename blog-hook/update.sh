cd blog
git pull origin
jekyll build -d $1
ruby beautify.rb $1
