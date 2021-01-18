Rails.application.config.middleware.insert_before Rack::Runtime, Rack::Timeout, service_timeout: Integer(ENV.fetch('RACK_TIMEOUT_SERVICE', 6))
