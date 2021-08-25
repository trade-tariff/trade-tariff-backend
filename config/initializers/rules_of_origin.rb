unless Rails.env.test?
  Rails.application.reloader.to_prepare do
    TradeTariffBackend.rules_of_origin_schemes # trigger loading at boot
  end
end
