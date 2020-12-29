module MailerEnvironment
  def subject_prefix(level = "info")
    "[#{Date.today}][#{TradeTariffBackend.deployed_environment}][#{TradeTariffBackend.deployed_service}][#{level}]"
  end
end
