module ProductionEnvironmentConfig
  class << self
    def configure(config)
      configure_runtime(config)
      configure_ssl(config)
      configure_logging(config)
      configure_cache(config)
      configure_mailer(config)
      configure_sidekiq_auth(config)
    end

    def configure_runtime(config)
      config.enable_reloading = false
      config.eager_load = true
      config.consider_all_requests_local = false
      config.action_controller.perform_caching = true
      config.public_file_server.enabled = false
    end

    def configure_ssl(config)
      force_ssl_enabled = ENV.fetch('RAILS_FORCE_SSL', 'false') == 'true'
      assume_ssl_enabled = force_ssl_enabled && ENV.fetch('RAILS_ASSUME_SSL', 'true') == 'true'

      config.force_ssl = force_ssl_enabled
      config.assume_ssl = assume_ssl_enabled
    end

    def configure_logging(config)
      config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new($stdout))
      config.lograge.enabled = true
      config.lograge.formatter = Lograge::Formatters::Logstash.new
      config.lograge.custom_options = lograge_custom_options
      config.lograge.ignore_actions = %w[
        HealthcheckController#index
        HealthcheckController#checkz
      ]
      config.silence_healthcheck_path = '/healthcheckz'
      config.log_tags = [:request_id]
      config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info')
      config.active_support.deprecation = :notify
    end

    def lograge_custom_options
      truncate_message = truncate_lograge_exception_message

      lambda do |event|
        exception = event.payload[:exception_object]
        exception_class, exception_message = event.payload[:exception]
        raw_exception_message = exception&.message || exception_message

        {
          request_id: event.payload[:request_id],
          auth_type: event.payload[:auth_type],
          client_id: event.payload[:client_id],
          accept: event.payload[:headers]&.[]('HTTP_ACCEPT'),
          exception_class: exception&.class&.name || exception_class,
          params: event.payload[:params].except('controller', 'action', 'format', 'utf8'),
          user_agent: event.payload[:user_agent],
        }.merge(truncate_message.call(raw_exception_message)).compact
      end
    end

    def truncate_lograge_exception_message
      max_length = 500

      lambda do |exception_message|
        next {} if exception_message.blank?

        message = exception_message.to_s

        {
          exception_message: message.first(max_length),
          exception_message_truncated: message.length > max_length,
        }
      end
    end

    def configure_cache(config)
      config.cache_store = :redis_cache_store,
                           TradeTariffBackend.redis_config.merge({
                             expires_in: 1.day,
                             namespace: "rails-cache-#{ENV['SERVICE'].presence || 'uk'}",
                             pool: { size: TradeTariffBackend.max_threads },
                           })
    end

    def configure_mailer(config)
      config.action_mailer.perform_caching = false
      config.action_mailer.delivery_method = :ses_v2
      config.i18n.fallbacks = [I18n.default_locale]
    end

    def configure_sidekiq_auth(config)
      config.middleware.use(SidekiqBasicAuth) do |username, password|
        secure_credential_compare(username, :username) &
          secure_credential_compare(password, :password)
      end
    end

    def secure_credential_compare(value, credential_key)
      ActiveSupport::SecurityUtils.secure_compare(
        ::Digest::SHA256.hexdigest(value),
        ::Digest::SHA256.hexdigest(Rails.application.credentials.dig(:sidekiq, credential_key)),
      )
    end
  end
end
