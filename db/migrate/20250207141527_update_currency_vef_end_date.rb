# frozen_string_literal: true

Sequel.migration do
  change do
    ExchangeRateCountryCurrency.where(currency_code: 'VEF').update(validity_end_date: Date.new(2025, 1, 31))
  end
end

