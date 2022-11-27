Sequel.migration do
  change do
    alter_table :news_collections do
      add_column :priority, Integer, default: 0, null: false
      add_column :description, String
    end
  end
end
