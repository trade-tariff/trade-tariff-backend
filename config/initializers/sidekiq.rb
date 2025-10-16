require 'sidekiq'
require 'custom_job_logger'
require 'trade_tariff_backend'

Sidekiq.strict_args!

Sidekiq.configure_server do |config|
  config.redis = TradeTariffBackend.redis_config
  config[:job_logger] = ::CustomJobLogger
end

Sidekiq.configure_client do |config|
  config.redis = TradeTariffBackend.redis_config
end
