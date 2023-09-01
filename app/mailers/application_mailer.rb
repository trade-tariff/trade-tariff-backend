class ApplicationMailer < ActionMailer::Base
  default from: TradeTariffBackend.from_email
end
