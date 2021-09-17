if Rails.env.production?
  Rails.application.config.middleware.insert_before Rack::Runtime, Rack::Timeout, service_timeout: Integer(ENV.fetch('RACK_TIMEOUT_SERVICE', 6))
else
  logger.info 'Rack::Runtime is disabled in Dev env.'
end
