require 'sinatra'

# Usage:
# ruby webhook.rb <dest-dir> -o <your-host>

# How to set webhook in bitbucket:
# https://confluence.atlassian.com/bitbucket/tutorial-create-and-trigger-a-webhook-747606432.html#Tutorial:CreateandTriggeraWebhook-Step2:Createthewebhook

# Clone the blog repo as directory 'blog'
# in the same path as 'update.sh''s

dest = ARGV[0]

post '/webhook' do
  system("bash update.sh #{dest}")
end
