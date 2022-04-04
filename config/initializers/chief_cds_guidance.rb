unless Rails.env.test?
  Rails.application.reloader.to_prepare do
    # trigger loading at boot
    require_relative '../../app/lib/trade_tariff_backend'

    TradeTariffBackend.chief_cds_guidance
  end
end
