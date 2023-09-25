Sequel.migration do
  up do
    drop_index :exchange_rate_currency_rates, %i[currency_code validity_start_date validity_end_date], unique: true
    add_index :exchange_rate_currency_rates, %i[currency_code validity_start_date validity_end_date rate_type], unique: true
  end

  down do
    drop_index :exchange_rate_currency_rates, %i[currency_code validity_start_date validity_end_date rate_type], unique: true
    add_index :exchange_rate_currency_rates, %i[currency_code validity_start_date validity_end_date], unique: true
  end
end
