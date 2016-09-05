cd blog
git pull origin
jekyll build -d $1
cd ..
ruby beautify.rb $1
