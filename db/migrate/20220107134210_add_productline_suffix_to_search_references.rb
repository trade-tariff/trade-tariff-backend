# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table :search_references do
      add_column :productline_suffix, String, null: false, default: '80'
    end
  end
end
