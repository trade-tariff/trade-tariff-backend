require 'sidekiq'
require 'custom_job_logger'
require 'trade_tariff_backend'

Sidekiq.strict_args!

Sidekiq.configure_server do |config|
  config.redis = TradeTariffBackend.sidekiq_redis_config
  config[:job_logger] = ::CustomJobLogger
  config.logger.formatter = Sidekiq::Logger::Formatters::JSON.new if Rails.env.production?

  config.death_handlers << lambda { |job, _exception|
    return unless TradeTariffBackend.slack_failures_enabled?
    return unless job.fetch('slack_alerts', true)

    SlackNotifierService.call(
      channel: TradeTariffBackend.slack_failures_channel,
      attachments: [
        {
          color: 'danger',
          title: ":fire: Job dead: #{job['class']}",
          fields: [
            { title: 'Error', value: "`#{job['error_class']}` — #{job['error_message']}", short: false },
            { title: 'JID', value: job['jid'], short: true },
            { title: 'Queue', value: job['queue'], short: true },
            { title: 'Args', value: "`#{job['args'].inspect}`", short: false },
            { title: 'Retries exhausted', value: job['retry_count'].to_s, short: true },
          ],
        },
      ],
    )
  }
end

Sidekiq.configure_client do |config|
  config.redis = TradeTariffBackend.sidekiq_redis_config
end
