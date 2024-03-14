# frozen_string_literal: true

Sequel.migration do
  up do
    if TradeTariffBackend.xi?
      drop_table :exchange_rate_countries
      drop_table :exchange_rate_countries_currencies
      drop_table :exchange_rate_currencies
      drop_table :exchange_rate_currency_rates
      drop_table :exchange_rate_files
    end
  end

  down do
    # Not irreversible
  end
end
