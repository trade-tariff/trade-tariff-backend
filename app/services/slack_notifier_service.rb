class SlackNotifierService
  class << self
    def call(message)
      if notifier.blank?
        # The notifier is only built in production with a webhook configured,
        # so an absent one used to make this a silent no-op. Callers treat a
        # Slack ping as their alerting channel, so say when one is dropped.
        Rails.logger.error('slack_notifier_unconfigured: dropped a Slack message because no notifier is configured')

        return nil
      end

      notifier.ping(message)
    end

  private

    def notifier
      Rails.application.config.slack_notifier
    end
  end
end
