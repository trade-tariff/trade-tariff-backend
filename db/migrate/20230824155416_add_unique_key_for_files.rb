Sequel.migration do
  up do
    alter_table :exchange_rate_files do
      add_unique_constraint %i[period_year period_month format type], name: 'unique_key_for_files'
    end
  end

  down do
    alter_table :exchange_rate_files do
      drop_constraint %i[period_year period_month format type], name: 'unique_key_for_files'
    end
  end
end
