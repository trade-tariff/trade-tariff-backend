# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:exchange_rate_files) do
      primary_key :id
      Integer :period_year, null: false
      Integer :period_month, null: false
      String :format, size: 20
      Integer :file_size
      Date :publication_date

      index :period_year
      index :period_month
    end
  end
end
