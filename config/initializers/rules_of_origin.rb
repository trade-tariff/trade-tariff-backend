unless Rails.env.test?
  Rails.application.reloader.to_prepare do
    # trigger loading at boot
    TradeTariffBackend.rules_of_origin_schemes
    TradeTariffBackend.rules_of_origin_rules
    TradeTariffBackend.rules_of_origin_mappings
  end
end
