source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?('/')
  "https://github.com/#{repo_name}.git"
end

ruby '~> 2.7.1'

# Server
gem 'puma', '~> 5.0.4'
gem 'rails', '>= 6.0.3.4'
gem 'sinatra', '~> 2.0.2'

# DB
gem 'pg', '~> 1.1', '>= 1.1.3'
gem 'sequel', '~> 5.22.0'
gem 'sequel-rails', '~> 1.0.0'

# File uploads and AWS
gem 'aws-sdk-rails', '~> 3'

# File zip/unzipping
gem 'rubyzip', '>= 2.3.0'

# Background jobs
gem 'redis-rails'
gem 'redlock', '~> 1.1.0'
gem 'sidekiq', '< 7'
gem 'sidekiq-scheduler', '~> 3.0.1'

# Elasticsearch
gem 'elasticsearch', '7.9.0'
gem 'elasticsearch-extensions', '0.0.31'

# Helpers
gem 'bootsnap', require: false
gem 'gds-sso', '~> 13', '>= 13.6.0'
gem 'hashie', '~> 4'
gem 'holidays'
gem 'lograge', '>= 0.3.6'
gem 'logstash-event'
gem 'nokogiri', '>= 1.10.9'
gem 'ox', '>= 2.8.1'
gem 'plek', '~> 1.11'
gem 'rack-timeout', '~> 0.4'
gem 'scout_apm'
gem 'sentry-raven'

# API related
gem 'ansi', '~> 1.5'
gem 'curb', '~> 0.9'
gem 'jsonapi-serializer'
gem 'rabl', '~> 0.14'
gem 'responders', '~> 3.0.0'
gem 'tilt'

# Printed PDF
gem 'combine_pdf'
gem 'sidekiq-batch'
gem 'uktt', '~> 0.2.16', git: 'https://github.com/TransformCore/uktt.git'

group :development do
  gem 'foreman'
  gem 'letter_opener'
  gem 'rubocop-govuk'
end

group :development, :test do
  gem 'dotenv-rails'
  gem 'pry-byebug'
  gem 'pry-rails'
end

group :test do
  gem 'database_cleaner'
  gem 'factory_bot_rails', require: false
  gem 'fakefs', '~> 0.18.0', require: 'fakefs/safe'
  gem 'forgery'
  gem 'json_expressions', '~> 0.9.0'
  gem 'rspec_junit_formatter'
  gem 'rspec-rails'
  gem 'simplecov', '~> 0.18', require: false
  gem 'webmock'
end
