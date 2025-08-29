# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table :tariff_updates do
      add_column :report_sent, TrueClass, default: false, null: false
    end
  end

  down do
    alter_table :tariff_updates do
      drop_column :report_sent
    end
  end
end
