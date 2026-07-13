require 'active_support/core_ext/integer/time'
require_relative 'development_environment_config'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  DevelopmentEnvironmentConfig.configure(config)
end
