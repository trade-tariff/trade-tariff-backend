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
gem 'aws-sdk-rails'
gem 'aws-sdk-s3'

# File zip/unzipping
gem 'rubyzip'

# Background jobs
gem 'redis-rails'
gem 'redlock'
gem 'sidekiq'
gem 'sidekiq-scheduler'

# Elasticsearch
gem 'elasticsearch', '~> 7.9.0' # Bumping this causes failures
gem 'elasticsearch-extensions'

# Helpers
gem 'bootsnap', require: false
gem 'gds-sso'
gem 'hashie'
gem 'holidays'
gem 'lograge'
gem 'logstash-event'
gem 'nokogiri'
gem 'omniauth-rails_csrf_protection'
gem 'ox'
gem 'plek'
gem 'sentry-raven'

# API related
gem 'ansi'
gem 'curb'
gem 'jsonapi-serializer'
gem 'rabl'
gem 'responders'
gem 'tilt'

# Newrelic
gem 'newrelic_rpm'

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
