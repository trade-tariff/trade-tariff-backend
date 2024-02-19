# frozen_string_literal: true

Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      old_liberian_country_currency = ExchangeRateCountryCurrency.where(country_description: 'Liberia').first

      old_liberian_country_currency.update(validity_end_date: Date.new(2023, 10, 31), currency_code: 'USD')

      nov_liberia_rate = ExchangeRateCountryCurrency.where(country_description: 'Liberia', validity_start_date: Date.new(2023, 11, 1)).first

      unless nov_liberia_rate
        ExchangeRateCountryCurrency.create(country_description: 'Liberia',
                                           currency_description: 'Dollar',
                                           country_code: 'LR',
                                           currency_code: 'LRD',
                                           validity_start_date: Date.new(2023, 11, 1))
      end
    end
  end

  down do
    # We don't want to rollback to incorrect Liberian rates.
  end
end
