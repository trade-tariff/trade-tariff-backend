SidekiqDeathHandler = lambda { |job, exception|
  return unless TradeTariffBackend.slack_failures_enabled?
  return unless job.fetch('slack_alerts', true)

  error_class = job['error_class'] || exception.class.name
  error_message = job['error_message'] || exception.message

  SlackNotifierService.call(
    channel: TradeTariffBackend.slack_failures_channel,
    attachments: [
      {
        color: 'danger',
        title: ":fire: Job dead: #{job['class']}",
        fields: [
          { title: 'Error', value: "`#{error_class}` - #{error_message}", short: false },
          { title: 'JID', value: job['jid'], short: true },
          { title: 'Queue', value: job['queue'], short: true },
          { title: 'Args', value: "`#{job['args'].inspect}`", short: false },
          { title: 'Retries exhausted', value: job['retry_count'].to_s, short: true },
        ],
      },
    ],
  )
}
