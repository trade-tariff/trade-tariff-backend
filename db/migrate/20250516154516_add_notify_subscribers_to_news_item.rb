# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table :news_items do
      add_column :notify_subscribers, TrueClass, default: false
    end
  end
end
