Sequel.migration do
  change do
    alter_table :news_collections do
      add_column :slug, String, size: 255, unique: true
    end
  end
end
