# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table :exchange_rate_files do
      add_column :type, String, null: false
      add_index :type
    end
  end

  down do
    alter_table :exchange_rate_files do
      drop_column :type
    end
  end
end
