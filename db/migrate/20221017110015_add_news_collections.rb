Sequel.migration do
  change do
    create_table :news_collections do
      primary_key :id
      String      :name, size: 255, null: false, unique: true
      Time        :created_at, null: false
      Time        :updated_at
    end
  end
end
