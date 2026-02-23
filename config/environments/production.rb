require 'active_support/core_ext/integer/time'

require_relative '../../app/lib/trade_tariff_backend'
require_relative '../../app/middleware/sidekiq_basic_auth'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot. This eager loads most of Rails and
  # your application in memory, allowing both threaded web servers
  # and those relying on copy on write to perform better.
  # Rake tasks automatically ignore this option for performance.
  config.eager_load = true

  # Full error reports are disabled and caching is turned on.
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true
  # Ensures that a master key has been made available in ENV["RAILS_MASTER_KEY"], config/master.key, or an environment
  # key such as config/credentials/production.key. This key is used to decrypt credentials (and other encrypted files).
  # config.require_master_key = true

  # Disable serving static files from `public/`, relying on NGINX/Apache to do so instead.
  config.public_file_server.enabled = false

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Specifies the header that your server uses for sending files.
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for Apache
  # config.action_dispatch.x_sendfile_header = "X-Accel-Redirect" # for NGINX

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # Can be used together with config.force_ssl for Strict-Transport-Security and secure cookies.
  # config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = false
  config.assume_ssl = ENV.fetch('RAILS_ASSUME_SSL', 'true') == 'true'

  # Log to STDOUT by default
  config.logger = ActiveSupport::Logger.new($stdout)
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Logstash.new
  config.lograge.custom_options = lambda do |event|
    {
      auth_type: event.payload[:auth_type],
      client_id: event.payload[:client_id],
      params: event.payload[:params].except('controller', 'action', 'format', 'utf8'),
      user_agent: event.payload[:user_agent],
    }.compact
  end

  config.lograge.ignore_actions = [
    'HealthcheckController#index',
    'HealthcheckController#checkz',
  ]

  config.silence_healthcheck_path = '/healthcheckz'

  # Rails cache store
  config.cache_store = :redis_cache_store,
                       TradeTariffBackend.redis_config.merge({
                         expires_in: 1.day,
                         namespace: "rails-cache-#{ENV['SERVICE'].presence || 'uk'}",
                         pool: { size: TradeTariffBackend.max_threads },
                         compress: true,
                         compress_threshold: 1.kilobyte,
                       })

  # Prepend all log lines with the following tags.
  config.log_tags = [:request_id]

  # Info include generic and useful information about system operation, but avoids logging too much
  # information to avoid inadvertent exposure of personally identifiable information (PII). If you
  # want to log everything, set the level to "debug".
  config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info')

  # Use a different cache store in production.
  # config.cache_store = :mem_cache_store

  # Use a real queuing backend for Active Job (and separate queues per environment).
  # config.active_job.queue_adapter = :resque
  # config.active_job.queue_name_prefix = "trade_tariff_backend_production"

  config.action_mailer.perform_caching = false

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false
  config.action_mailer.delivery_method = :ses_v2

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = [I18n.default_locale]

  # Send deprecation notices to registered listeners.
  config.active_support.deprecation = :notify
  config.middleware.use(SidekiqBasicAuth) do |username, password|
    ActiveSupport::SecurityUtils.secure_compare(
      ::Digest::SHA256.hexdigest(username),
      ::Digest::SHA256.hexdigest(Rails.application.credentials.dig(:sidekiq, :username)),
    ) &
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(password),
        ::Digest::SHA256.hexdigest(Rails.application.credentials.dig(:sidekiq, :password)),
      )
  end
end
