# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:exchange_rate_currency_rates) do
      primary_key :id
      String :currency_code, size: 10, null: false
      Date :validity_start_date
      Date :validity_end_date
      Float :rate
      String :rate_type, size: 10

      index :currency_code
      index :validity_start_date
      index :validity_end_date
      index %i[currency_code validity_start_date validity_end_date], unique: true
    end
  end
end
