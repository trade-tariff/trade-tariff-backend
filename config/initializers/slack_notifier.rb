slack_env_defined = ENV['SLACK_WEB_HOOK_URL'] && ENV['SLACK_CHANNEL'] && ENV['SLACK_USERNAME']

Rails.application.config.slack_notifier = if Rails.env.production? && slack_env_defined
                                            Slack::Notifier.new(
                                              ENV['SLACK_WEB_HOOK_URL'],
                                              channel: ENV['SLACK_CHANNEL'],
                                              username: ENV['SLACK_USERNAME'],
                                            )
                                          end
