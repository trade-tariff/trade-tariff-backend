Sequel.migration do
  up do
    ved_currency = ExchangeRateCountryCurrency.where(currency_code: 'VED',country_code:'VE').first
    ved_currency.update(validity_end_date: Date.new(2026, 01, 15))
    ved_currency.save

    ExchangeRateCountryCurrency.create(country_description: 'Venezuela',
                                         currency_code: 'VEF',
                                         country_code:'VE',
                                         currency_description: 'Bolivar Fuerte',
                                         validity_start_date: Date.new(2026,01,16),
                                         validity_end_date: nil,)

  end

  down do
    # We don't want to roll back to incorrect Venezuela rates.
  end
end
