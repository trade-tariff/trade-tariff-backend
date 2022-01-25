require 'slack-notifier'

class FakeSlackNotifier
  def ping(_message); end
end

slack_notifier = if Rails.env.production?
                   if ENV['SLACK_WEB_HOOK_URL'] && ENV['SLACK_CHANNEL'] && ENV['SLACK_USERNAME']
                     Slack::Notifier.new(ENV['SLACK_WEB_HOOK_URL'],
                                         channel: ENV['SLACK_CHANNEL'],
                                         username: ENV['SLACK_USERNAME'])
                   else
                     logger.warn('The ENV SLACK_WEB_HOOK_URL, SLACK_CHANNEL or SLACK_USERNAME are not declared. ' \
                                 'Slack notifications are disabled.')
                     nil
                   end
                 end

Rails.application.config.slack_notifier = slack_notifier || FakeSlackNotifier.new
