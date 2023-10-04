Sequel.migration do
  up do
    create_table :exchange_rate_countries_currencies do
      primary_key :id
      String :country_code, null: false # The ISO 3166-1 alpha-2 code of the country
      String :country_description, null: false # The description of the country
      String :currency_code, null: false # The ISO 4217 currency code for the country
      String :currency_description, null: false # The description of the currency
      Date :validity_start_date, null: false # The date the currency became valid for the country
      Date :validity_end_date # The date the currency no longer applies for the country (a nil value here means the descriptions for the country and currency are still valid)
      DateTime :created_at, null: false
      DateTime :updated_at, null: false

      index :currency_code # We join on this field
      index :validity_start_date # We filter on this field
      index :validity_end_date # We filter on this field
      index %i[
        currency_code
        country_code
        validity_start_date
        validity_end_date
      ], unique: true # We upsert on conflicts of these fields
    end
  end

  down do
    drop_table :exchange_rate_countries_currencies
  end
end
