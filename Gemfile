source 'https://rubygems.org'

ruby File.read('.ruby-version')

# Server
gem 'puma', '~> 5.3.1'
gem 'rails', '>= 6.0.3.4'

# DB
gem 'pg', '~> 1.1', '>= 1.1.3'
gem 'sequel', '~> 5.22.0'
gem 'sequel-rails', '~> 1.1.1'

# File uploads and AWS
gem 'aws-sdk-rails'
gem 'aws-sdk-s3'

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
gem 'gds-sso'
gem 'hashie', '~> 4'
gem 'holidays'
gem 'lograge', '>= 0.3.6'
gem 'logstash-event'
gem 'nokogiri', '>= 1.10.9'
gem 'ox', '>= 2.8.1'
gem 'plek', '~> 1.11'
gem 'rack-timeout', '~> 0.4'
gem 'sentry-raven'

# API related
gem 'ansi', '~> 1.5'
gem 'curb', '~> 0.9'
gem 'jsonapi-serializer'
gem 'rabl', '~> 0.14'
gem 'responders', '~> 3.0.0'
gem 'tilt'

# Newrelic
gem 'newrelic_rpm'

group :development do
  gem 'foreman'
  gem 'github_changelog_generator'
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
  gem 'fakefs', '~> 1.3.2', require: 'fakefs/safe'
  gem 'forgery'
  gem 'json_expressions', '~> 0.9.0'
  gem 'rspec-json_expectations'
  gem 'rspec_junit_formatter'
  gem 'rspec-rails'
  gem 'simplecov', '~> 0.18', require: false
  gem 'webmock'
end
