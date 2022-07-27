unless Rails.env.test?
  Rails.application.reloader.to_prepare do
    # trigger loading at boot
    require_relative '../../app/lib/trade_tariff_backend'

    TradeTariffBackend.search_facet_classifier_configuration.all_filters
  end
end
