Sequel.migration do
  change do
    alter_table :news_items do
      add_column :imported_at, DateTime
    end
  end
end
