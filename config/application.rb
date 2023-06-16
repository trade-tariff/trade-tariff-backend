require_relative 'boot'
require_relative '../lib/core_ext/object'

require 'action_controller/railtie'
require 'action_mailer/railtie'
# require "sprockets/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TradeTariffBackend
  class Application < Rails::Application
    config.api_only = true
    config.debug_exception_response_format = :default

    config.load_defaults 6.1

    config.generators do |g|
      g.view_specs     false
      g.helper_specs   false
      g.test_framework false
    end

    config.time_zone = 'UTC'

    config.intercept_messages = config_for(:intercept_messages)

    config.api_only = true

    config.sequel.schema_format = :sql
    config.sequel.default_timezone = :utc

    config.sequel.after_connect = proc do
      Sequel::Model.plugin :take
      Sequel::Model.plugin :validation_class_methods

      Sequel::Model.db.extension :pagination
      Sequel::Model.db.extension :server_block
      Sequel::Model.db.extension :auto_literal_strings
      Sequel::Model.db.extension :pg_array
      Sequel::Model.db.extension :null_dataset
    end

    # Tells Rails to serve error pages from the app itself, rather than using static error pages in public/
    config.exceptions_app = routes

    config.middleware.use Rack::Deflater
    config.sequel.allow_missing_migration_files = \
      (ENV['ALLOW_MISSING_MIGRATION_FILES'].to_s == 'true')
  end

  Rails.autoloaders.main.ignore(Rails.root.join('lib/core_ext'))
end
