require 'sidekiq'
require 'query_count_job_logger'
require 'trade_tariff_backend'

Sidekiq.strict_args!

Sidekiq.configure_server do |config|
  config.redis = TradeTariffBackend.redis_config
  config[:job_logger] = ::QueryCountJobLogger
end

Sidekiq.configure_client do |config|
  config.redis = TradeTariffBackend.redis_config
end

Rails.application.config.filter_parameters += %i[
  passw email secret token _key crypt salt certificate otp ssn cvv cvc
]
