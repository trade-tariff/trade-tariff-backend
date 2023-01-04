class SlackNotifierService
  class << self
    def call(message)
      notifier.ping(message) if notifier.present?
    end

    private

    def notifier
      Rails.application.config.slack_notifier
    end
  end
end
