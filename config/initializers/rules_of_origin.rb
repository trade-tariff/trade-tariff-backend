unless Rails.env.test?
  Rails.application.reloader.to_prepare do
    # trigger loading at boot
    TradeTariffBackend.rules_of_origin
  end
end
