class SchemaQueryFilterLogger < SimpleDelegator
  SCHEMA_QUERY_PATTERN = /pg_attribute|current_setting/

  def debug(progname = nil, &block)
    return if SCHEMA_QUERY_PATTERN.match?(progname)

    super(progname, &block)
  end
end

module DevelopmentEnvironmentConfig
  class << self
    def configure(config)
      configure_reloading(config)
      configure_error_reporting(config)
      configure_caching(config)
      configure_mailer(config)
      configure_deprecations(config)
      configure_development_diagnostics(config)
    end

    def configure_reloading(config)
      config.enable_reloading = true
      config.eager_load = false
    end

    def configure_error_reporting(config)
      config.action_dispatch.show_exceptions = :all
      config.consider_all_requests_local = true
      config.server_timing = true
    end

    def configure_caching(config)
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
    end

    def configure_mailer(config)
      config.action_mailer.raise_delivery_errors = false
      config.action_mailer.perform_caching = false
      config.action_mailer.default_url_options = {
        host: ENV.fetch('DEFAULT_MAIL_HOST', 'host.docker.internal'),
        port: 3000,
      }
      config.action_mailer.delivery_method = :letter_opener
    end

    def configure_deprecations(config)
      config.active_support.deprecation = :log
      config.active_support.disallowed_deprecation = :raise
      config.active_support.disallowed_deprecation_warnings = []
    end

    def configure_development_diagnostics(config)
      # enable sequel transaction logs by setting RAILS_LOG_LEVEL=debug
      config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info').to_sym
      config.active_job.verbose_enqueue_logs = true
      config.action_controller.raise_on_missing_callback_actions = true

      config.after_initialize do
        Rails.logger = SchemaQueryFilterLogger.new(Rails.logger)
      end
    end
  end
end
