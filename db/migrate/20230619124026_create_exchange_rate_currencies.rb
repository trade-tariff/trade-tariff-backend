# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:exchange_rate_currencies) do
      String :currency_code, size: 10, unique: true, primary_key: true, null: false
      String :currency_description, size: 200
      TrueClass :spot_rate_required, default: false

      index :currency_code
    end
  end
end
