# frozen_string_literal: true

Sequel.migration do
  change do
    create_table :exchange_rate_country_histories do
      primary_key :id
      String :country, size: 200, unique: true, null: false
      String :country_code, size: 10, unique: true, null: false
      String :currency_code, size: 10, null: false
      String :currency_description, size: 200, null: false
      Date :start_date, null: false
      Date :end_date

      index :country, unique: true
      index %i[country country_code], unique: true
    end
  end
end
