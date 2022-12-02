Sequel.migration do
  change do
    alter_table :news_collections do
      add_column :slug, String, size: 255, unique: true
      add_column :published, :boolean, default: true
    end
  end
end
