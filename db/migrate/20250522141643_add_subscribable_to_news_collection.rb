# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table :news_collections do
      add_column :subscribable, TrueClass, default: false
    end
  end
end
