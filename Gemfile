# This is a test
source 'https://rubygems.org'

ruby File.read('.ruby-version')

# Server
gem 'puma'
gem 'rails', '~> 7.1'

# DB
gem 'pg'
gem 'sequel'
gem 'sequel-rails'

# File uploads and AWS
gem 'aws-sdk-rails'
gem 'aws-sdk-s3'

# File zip/unzipping
gem 'rubyzip'

# Background jobs
gem 'connection_pool'
gem 'redis', '>= 5.0.6'
gem 'redis-client', '>= 0.11.2'
gem 'redlock'
gem 'sidekiq', '< 8'
gem 'sidekiq-scheduler'

# Elasticsearch
gem 'opensearch-ruby'

# Helpers
gem 'bootsnap', require: false
gem 'caxlsx'
gem 'gds-sso'
gem 'hashie'
gem 'holidays'
gem 'lemmatizer'
gem 'lograge'
gem 'logstash-event'
gem 'nokogiri'
gem 'omniauth-rails_csrf_protection'
gem 'plek'
gem 'routing-filter', github: 'svenfuchs/routing-filter'
gem 'sentry-rails'
gem 'sentry-sidekiq'
gem 'slack-notifier'

# API related
gem 'ansi'
gem 'jsonapi-serializer'
gem 'rabl'
gem 'responders'
gem 'tilt'

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
  gem 'brakeman'
  gem 'database_cleaner-sequel'
  gem 'factory_bot_rails', require: false
  gem 'fakefs', require: 'fakefs/safe'
  gem 'forgery'
  gem 'json_expressions'
  gem 'rspec-json_expectations'
  gem 'rspec_junit_formatter'
  gem 'rspec-rails'
  gem 'simplecov', require: false
  gem 'webmock'
end

group :production do
  gem 'rack-timeout'
end
