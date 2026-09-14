class SlackNotifierService
  class << self
    def call(message = nil, **options)
      payload = options.dup
      payload[:text] = message unless message.nil?

      notifier.presence&.ping(payload)
    end

  private

    def notifier
      Rails.application.config.slack_notifier
    end
  end
end
