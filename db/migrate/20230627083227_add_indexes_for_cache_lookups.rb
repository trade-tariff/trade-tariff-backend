# frozen_string_literal: true

Sequel.migration do
  up do
    add_index :tariff_updates, :issue_date
  end

  down do
    drop_index :tariff_updates, :issue_date
  end
end
