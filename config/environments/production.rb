require 'active_support/core_ext/integer/time'

require_relative '../../app/lib/trade_tariff_backend'
require_relative 'production_environment_config'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  ProductionEnvironmentConfig.configure(config)
end
