class SlackNotifierService
  UNCONFIGURED_MESSAGE = 'slack_notifier_unconfigured: dropped a Slack message because no notifier is configured'.freeze

  class << self
    def call(message)
      if notifier.blank?
        log_unconfigured

        return nil
      end

      notifier.ping(message)
    end

  private

    # config/initializers/slack_notifier.rb builds a notifier in production
    # alone, so production is the only place where a blank one is a fault: it
    # means a webhook is missing from the environment that sends the alerts.
    # Everywhere else a blank notifier is the configured state, and an error
    # log there is noise that hides the production signal.
    def log_unconfigured
      if Rails.env.production?
        Rails.logger.error(UNCONFIGURED_MESSAGE)
      else
        Rails.logger.debug(UNCONFIGURED_MESSAGE)
      end
    end

    def notifier
      Rails.application.config.slack_notifier
    end
  end
end
