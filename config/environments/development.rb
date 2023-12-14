class SchemaQueryFilterLogger < SimpleDelegator
  SCHEMA_QUERY_PATTERN = /pg_attribute|current_setting/

  def debug(progname = nil, &block)
    return if progname =~ SCHEMA_QUERY_PATTERN

    super(progname, &block)
  end
end

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # In the development environment your application's code is reloaded on
  # every request. This slows down response time but is perfect for development
  # since you don't have to restart the web server when you make code changes.
  config.cache_classes = false

  # Do not eager load code on boot.
  config.eager_load = false

  # Log error messages when you accidentally call methods on nil.
  config.whiny_nils = true

  # Show full error reports and disable caching
  config.consider_all_requests_local = true

  if Rails.root.join('tmp/caching-dev.txt').exist?
    config.action_controller.perform_caching = true
    config.action_controller.enable_fragment_cache_logging = true

    config.cache_store = :memory_store
    config.public_file_server.headers = {
      'Cache-Control' => "public, max-age=#{2.days.to_i}",
    }
  else
    config.action_controller.perform_caching = false

    config.cache_store = :null_store
  end

  # enable sequel transaction logs by setting RAILS_LOG_LEVEL=debug
  config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info').to_sym

  # Don't care if the mailer can't send.
  config.action_mailer.raise_delivery_errors = false

  config.action_mailer.perform_caching = false

  # Mailcatcher configuration.
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
  config.action_mailer.delivery_method = :letter_opener

  # Print deprecation notices to the Rails logger.
  config.active_support.deprecation = :log

  # Only use best-standards-support built into browsers.
  config.action_dispatch.best_standards_support = :builtin

  # Do not compress assets.
  # config.assets.compress = false

  # Suppress logger output for asset requests.
  # config.assets.quiet = true

  # Expands the lines which load the assets.
  # config.assets.debug = true

  # Raises error for missing translations
  # config.action_view.raise_on_missing_translations = true
  config.logger = SchemaQueryFilterLogger.new(ActiveSupport::Logger.new($stdout))
end
