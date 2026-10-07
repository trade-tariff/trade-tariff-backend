module SidekiqDeathHandler
  MAXIMUM_BACKTRACE_LINES = 10

  def self.call(job, exception)
    return unless TradeTariffBackend.slack_failures_enabled?
    return unless job.fetch('slack_alerts', true)

    error_class = job['error_class'] || exception.class.name
    error_message = job['error_message'] || exception.message
    channel = job['slack_channel'].presence || TradeTariffBackend.slack_failures_channel

    SlackNotifierService.call(
      channel:,
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
            { title: 'Backtrace', value: backtrace_text(exception), short: false },
            { title: 'Logs', value: "<#{logs_url(job)}|View logs in CloudWatch>", short: false },
          ],
        },
      ],
    )
  end

  def self.backtrace_text(exception)
    lines = Array(exception.backtrace).first(MAXIMUM_BACKTRACE_LINES)
    return 'No backtrace' if lines.empty?

    "```#{lines.join("\n")}```"
  end

  # Sidekiq sets failed_at (epoch milliseconds) on the first failure. The log
  # window starts there, so the link shows every failed attempt, not only the last.
  def self.logs_url(job)
    from = if job['failed_at']
             Time.zone.at(job['failed_at'] / 1000.0) - 5.minutes
           else
             Time.zone.now - 15.minutes
           end

    CloudwatchLogsInsightsLink.for_job(jid: job['jid'], from:, to: Time.zone.now + 5.minutes)
  end

  private_class_method :backtrace_text, :logs_url
end
