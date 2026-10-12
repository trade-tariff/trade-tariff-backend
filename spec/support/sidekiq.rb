# Expected failure paths log at error. Keep those lines out of the progress
# formatter; specs that care still stub Sidekiq.logger and assert the message.
Sidekiq.logger.level = Logger::FATAL
Sidekiq.testing!(:fake)
