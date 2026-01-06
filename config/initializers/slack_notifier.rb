Rails.application.config.slack_notifier = if Rails.env.production? && TradeTariffBackend.slack_web_hook_url.present?
                                            Slack::Notifier.new(
                                              TradeTariffBackend.slack_web_hook_url,
                                              channel: TradeTariffBackend.slack_channel,
                                              username: TradeTariffBackend.slack_username,
                                            )
                                          end
