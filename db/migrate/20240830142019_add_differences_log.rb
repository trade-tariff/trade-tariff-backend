# frozen_string_literal: true

Sequel.migration do
  up do
    create_table :differences_logs do
      primary_key :id
      Date :date, null: false
      String :key, null: false
      Text :value, null: false
    end
  end

  down do
    drop_table :differences_logs
  end
end
