# frozen_string_literal: true

Sequel.migration do
  change do
    Sequel::Model.db.run "INSERT INTO exchange_rate_currencies (currency_code, currency_description, spot_rate_required) VALUES ('VED', 'Bolivar Fuerte', true)"

    ExchangeRateCountryCurrency.where(currency_code: 'VEF').update(validity_end_date: Date.new(2025, 1, 15))
    ExchangeRateCountryCurrency.create(
      currency_code: 'VED',
      country_code: 'VE',
      country_description: 'Venezuela',
      currency_description: 'Bolivar Fuerte',
      validity_start_date: Date.new(2025, 1, 22),
    )
  end
end
