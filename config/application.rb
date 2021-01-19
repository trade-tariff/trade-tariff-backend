require_relative 'boot'

require 'action_controller/railtie'
require 'action_mailer/railtie'
# require "sprockets/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TradeTariffBackend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.0
    require 'trade_tariff_backend'

    # lib directory to be autoloadable.
    config.eager_load_paths << Rails.root.join('lib')

    config.autoloader = :classic

    config.generators do |g|
      g.view_specs     false
      g.helper_specs   false
      g.test_framework false
    end

    config.time_zone = 'UTC'

    # Enable the asset pipeline
    # config.assets.enabled = false

    # Configure sequel
    config.sequel.schema_format = :sql
    config.sequel.default_timezone = :utc

    config.sequel.after_connect = proc do
      Sequel::Model.plugin :take
      Sequel::Model.plugin :validation_class_methods

      Sequel::Model.db.extension :pagination
      Sequel::Model.db.extension :server_block
      Sequel::Model.db.extension :auto_literal_strings
    end

    # GA measurements protocol event tracking
    config.google_analytics_tracking_id = ENV['GOOGLE_ANALYTICS_TRACKING_ID']
  end
end
