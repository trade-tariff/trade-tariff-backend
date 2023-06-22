# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:exchange_rate_countries) do
      String :currency_code, size: 10
      String :country, size: 200
      String :country_code, size: 10, unique: true, primary_key: true, null: false
      TrueClass :active

      index :currency_code
      index :country_code
    end
  end
end
