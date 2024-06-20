# frozen_string_literal: true

Sequel.migration do
  up do
    if TradeTariffBackend.uk?
      zimbabwe_gold_country_currency = ExchangeRateCountryCurrency.where(country_description: 'Zimbabwe',currency_code: 'ZIG',country_code:'ZW').first

      zimbabwe_gold_country_currency.update(currency_description: 'Zimbabwe Gold')
      zimbabwe_gold_country_currency.save
    end
  end

  down do
    # We don't want to rollback to incorrect Zimbabwe rates.
  end
end
