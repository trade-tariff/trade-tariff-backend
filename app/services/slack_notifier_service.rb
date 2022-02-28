class SlackNotifierService
  def call(message)
    Rails.application.config.slack_notifier.ping(message)
  end
end
