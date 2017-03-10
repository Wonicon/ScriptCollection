cd blog
git pull origin
JEKYLL_ENV=production jekyll build -d $1
cd ..
ruby beautify.rb $1
