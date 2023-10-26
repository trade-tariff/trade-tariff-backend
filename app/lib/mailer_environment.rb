module MailerEnvironment
  def subject_prefix(level = 'info')
    "[#{Time.zone.today}][#{TradeTariffBackend.deployed_environment}][#{TradeTariffBackend.service}][#{level}]"
  end
end
