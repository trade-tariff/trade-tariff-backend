require 'sidekiq'
require 'custom_job_logger'
require 'sidekiq_death_handler'
require 'trade_tariff_backend'

Sidekiq.strict_args!

Sidekiq.configure_server do |config|
  config.redis = TradeTariffBackend.sidekiq_redis_config
  config[:job_logger] = ::CustomJobLogger
  config.logger.formatter = Sidekiq::Logger::Formatters::JSON.new if Rails.env.production?

  config.death_handlers << SidekiqDeathHandler

  capsule_config = TradeTariffBackend::SidekiqCapsuleConfig.new
  capsule_config.apply!(config)
  config.logger.info(
    'event' => 'sidekiq_capsules_configured',
    'total_concurrency' => config.total_concurrency,
    'capsules' => capsule_config.capsules.map do |capsule|
      {
        'name' => capsule.name,
        'concurrency' => capsule.concurrency,
        'queues' => capsule.queues,
      }
    end,
  )
end

Sidekiq.configure_client do |config|
  config.redis = TradeTariffBackend.sidekiq_redis_config
end
