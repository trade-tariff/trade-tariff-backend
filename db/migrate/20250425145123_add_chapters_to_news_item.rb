# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table :news_items do
      add_column :chapters, String
    end
  end
end
