# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table :exchange_rate_currency_rates do
      add_index :rate_type
    end
  end

  down do
    alter_table :exchange_rate_currency_rates do
      drop_index :rate_type
    end
  end
end
