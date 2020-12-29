module MailerEnvironment
  def subject_prefix(level = "info")
    "[#{Date.today}][#{TradeTariffBackend.deployed_environment}][#{TradeTariffBackend.service}][#{level}]"
  end
end
