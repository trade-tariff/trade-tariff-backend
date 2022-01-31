# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table :search_references do
      add_column :leaf, FalseClass, null: true
    end
  end
end
