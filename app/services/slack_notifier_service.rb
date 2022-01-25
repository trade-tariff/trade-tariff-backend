class SlackNotifierService
  class << self
    def call(message)
      notifier.ping(message)
    end

  private
    def notifier
      Rails.application.config.slack_notifier
    end
  end
end
