require_relative 'boot'
require_relative '../lib/core_ext/object'
require_relative '../app/middleware/handle_goods_nomenclature'
require_relative '../app/middleware/clear_cache_control'

require 'action_controller/railtie'
require 'action_mailer/railtie'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TradeTariffBackend
  class Application < Rails::Application
    config.debug_exception_response_format = :default

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    config.generators do |g|
      g.view_specs     false
      g.helper_specs   false
      g.test_framework false
    end

    config.time_zone = 'UTC'

    config.intercept_messages = config_for(:intercept_messages)

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    config.sequel.schema_format = :sql
    config.sequel.default_timezone = :utc

    config.sequel.after_connect = proc do
      Sequel::Model.plugin :take
      Sequel::Model.plugin :validation_class_methods
      Sequel::Model.plugin :optimized_many_to_many

      Sequel::Model.db.extension :pagination
      Sequel::Model.db.extension :server_block
      Sequel::Model.db.extension :auto_literal_strings
      Sequel::Model.db.extension :pg_array
      Sequel::Model.db.extension :null_dataset
    end

    # Tells Rails to serve error pages from the app itself, rather than using static error pages in public/
    config.exceptions_app = routes

    config.sequel.allow_missing_migration_files = ENV['ALLOW_MISSING_MIGRATION_FILES'].to_s == 'true'

    config.middleware.use ::HandleGoodsNomenclature
    config.middleware.insert_before Rack::ETag, ::ClearCacheControl
  end

  Rails.autoloaders.main.ignore(Rails.root.join('lib/core_ext'))
  Rails.autoloaders.main.ignore(Rails.root.join('lib/generators'))
end
