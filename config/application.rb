require_relative 'boot'
require_relative '../app/lib/core_ext/object'

require 'action_controller/railtie'
require 'action_mailer/railtie'
# require "sprockets/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TradeTariffBackend
  class Application < Rails::Application
    config.load_defaults 6.0

    config.generators do |g|
      g.view_specs     false
      g.helper_specs   false
      g.test_framework false
    end

    config.time_zone = 'UTC'

    config.sequel.schema_format = :sql
    config.sequel.default_timezone = :utc

    config.sequel.after_connect = proc do
      Sequel::Model.plugin :take
      Sequel::Model.plugin :validation_class_methods

      Sequel::Model.db.extension :pagination
      Sequel::Model.db.extension :server_block
      Sequel::Model.db.extension :auto_literal_strings
    end

    config.sequel.allow_missing_migration_files = \
      (ENV['ALLOW_MISSING_MIGRATION_FILES'].to_s == 'true')
  end

  Rails.autoloaders.main.ignore(Rails.root.join('app/lib/core_ext'))
end
