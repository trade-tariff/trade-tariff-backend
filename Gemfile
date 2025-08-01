source 'https://rubygems.org'

ruby File.read('.ruby-version')

# Server
gem 'puma'
gem 'rails'

# DB
gem 'pg'
gem 'sequel'
gem 'sequel-rails'

# File uploads and AWS
gem 'aws-actionmailer-ses'
gem 'aws-sdk-cloudfront', '~> 1.119'
gem 'aws-sdk-rails'
gem 'aws-sdk-s3'

# File zip/unzipping
gem 'rubyzip'

# Background jobs
gem 'connection_pool'
gem 'redis'
gem 'redis-client'
gem 'redlock'
gem 'sidekiq'
gem 'sidekiq-scheduler'

# Elasticsearch
gem 'opensearch-ruby'

# Helpers
gem 'bootsnap', require: false
gem 'caxlsx'
gem 'csv'
gem 'gds-sso'
gem 'hashie'
gem 'holidays'
gem 'lograge'
gem 'logstash-event'
gem 'newrelic_rpm'
gem 'nokogiri'
gem 'notifications-ruby-client'
gem 'omniauth-rails_csrf_protection'
gem 'ostruct'
gem 'plek'
gem 'slack-notifier'

# API related
gem 'jsonapi-serializer'
gem 'rabl'
gem 'responders'
gem 'tilt'

group :development do
  gem 'foreman'
  gem 'letter_opener'
  gem 'rubocop-govuk'
  gem 'rubocop-performance'
end

group :development, :test do
  gem 'awesome_print'
  gem 'dotenv-rails'
  gem 'pry-rails'
  gem 'ruby-lsp-rails'
  gem 'ruby-lsp-rspec'
  gem 'factory_bot_rails', require: false
end

group :test do
  gem 'brakeman'
  gem 'database_cleaner-sequel'
  gem 'forgery'
  gem 'json_expressions'
  gem 'rspec-ctrf'
  gem 'rspec-json_expectations'
  gem 'rspec_junit_formatter'
  gem 'rspec-rails'
  gem 'rspec-rebound'
  gem 'webmock'
end

group :production do
  gem 'rack-attack'
  gem 'rack-timeout'
end
