Sequel.migration do
  change do
    alter_table :news_items do
      add_column :precis, String
      add_column :slug, String, size: 255, unique: true

      add_index :slug
    end
  end
end
