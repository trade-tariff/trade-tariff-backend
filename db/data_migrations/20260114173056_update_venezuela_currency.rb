Sequel.migration do
  up do
    if TradeTariffBackend.uk? && ExchangeRateCountryCurrency.where(currency_code: 'VES', country_code: 'VE').count.zero?
      ved_currency = ExchangeRateCountryCurrency.find(currency_code: 'VED', country_code: 'VE')
      ved_currency.update(validity_end_date: Date.new(2025, 12, 31))

      ExchangeRateCountryCurrency.create(country_description: 'Venezuela',
                                         currency_code: 'VES',
                                         country_code: 'VE',
                                         currency_description: 'Venezuelan Bolivar',
                                         validity_start_date: Date.new(2026, 1, 1),
                                         validity_end_date: nil)
    end
  end

  down do
    # We don't want to roll back to incorrect Venezuela rates.
  end
end
