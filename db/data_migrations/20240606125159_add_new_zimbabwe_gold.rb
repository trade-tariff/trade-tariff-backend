# frozen_string_literal: true

Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      new_zimbabwe_country_currency = ExchangeRateCountryCurrency.where(country_description: 'Zimbabwe',
                                                                        currency_code: 'ZIG',
                                                                        country_code:'ZW').first

      zimbabwe_country_currency.update(country_description: 'Zimbabwe Gold')
    end
  end

  down do
    # We don't want to rollback to incorrect Zimbabwe rates.
  end
end
