# frozen_string_literal: true

Sequel.migration do
  up do
    drop_table :exchange_rate_countries
    drop_table :exchange_rate_currencies
  end

  down do
    # No reverting
  end
end
