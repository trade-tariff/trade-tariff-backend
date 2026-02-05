require 'sidekiq/component'
require 'sidekiq/job_logger'

class CustomJobLogger < ::Sidekiq::JobLogger
  def call(item, queue)
    start = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
    reset_query_count
    yield
    duration = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - start

    Sidekiq.logger.info(
      'class' => item['class'],
      'jid' => item['jid'],
      'queue' => queue,
      'args' => item['args'],
      'duration' => duration,
      'queries' => query_count,
      'status' => 'done',
    )
  rescue StandardError => e
    duration = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - start

    Sidekiq.logger.warn(
      'class' => item['class'],
      'jid' => item['jid'],
      'queue' => queue,
      'args' => item['args'],
      'duration' => duration,
      'queries' => query_count,
      'status' => 'fail',
      'error_class' => e.class.name,
      'error_message' => e.message,
    )

    begin
      alert_slack(e, item) if should_alert_slack?(item)
    rescue StandardError => slack_error
      Sidekiq.logger.error("Failed to send Slack alert: #{slack_error.class.name} - #{slack_error.message}")
    end

    raise e
  end

  private

  def should_alert_slack?(item)
    return false unless TradeTariffBackend.slack_failures_enabled?

    # Allow workers to opt-out of Slack alerts via sidekiq_options
    item.fetch('slack_alerts', true)
  end

  def alert_slack(error, item)
    text = "Job Failed: #{item['class']} (JID: #{item['jid']})\n" \
           "Error: #{error.class.name} - #{error.message}\n" \
           "Args: #{item['args'].inspect}"

    SlackNotifierService.call(
      text: text,
      channel: TradeTariffBackend.slack_failures_channel,
    )
  end

  def query_count
    ::SequelRails::Railties::LogSubscriber.count
  end

  def reset_query_count
    ::SequelRails::Railties::LogSubscriber.reset_count
  end
end
