require 'sidekiq'
require 'custom_job_logger'
require 'trade_tariff_backend'

Sidekiq.strict_args!

Sidekiq.configure_server do |config|
  config.redis = TradeTariffBackend.sidekiq_redis_config
  config[:job_logger] = ::CustomJobLogger
  config.logger.formatter = Sidekiq::Logger::Formatters::JSON.new if Rails.env.production?
end

Sidekiq.configure_client do |config|
  config.redis = TradeTariffBackend.sidekiq_redis_config
end
