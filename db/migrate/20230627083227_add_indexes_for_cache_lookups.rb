# frozen_string_literal: true

Sequel.migration do
  up do
    add_index :tariff_updates, :issue_date
    add_index :news_items, %i[updated_at start_date end_date]
  end

  down do
    drop_index :news_items, %i[updated_at start_date_end_date]
    drop_index :tariff_updates, :issue_date
  end
end
