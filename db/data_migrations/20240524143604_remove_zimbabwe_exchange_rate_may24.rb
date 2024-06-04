# frozen_string_literal: true

Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      zimbabwe_country_currency = ExchangeRateCountryCurrency.where(country_description: 'Zimbabwe',
                                                                    currency_code: 'ZWL',
                                                                    country_code:'ZW').first

      zimbabwe_country_currency.update(validity_end_date: Date.new(2024, 06, 01))

      ExchangeRateCountryCurrency.create(country_description: 'Zimbabwe',
                                         currency_code: 'ZIG',
                                         country_code:'ZW',
                                         currency_description: 'Dollar',
                                         validity_start_date: Date.new(2024,06,01),
                                         validity_end_date: nil,)

    end
  end

  down do
    # We don't want to rollback to incorrect Zimbabwe rates.
  end
end
