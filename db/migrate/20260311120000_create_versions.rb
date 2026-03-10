Sequel.migration do
  change do
    create_table :versions do
      primary_key :id
      String :item_type, null: false
      String :item_id, null: false
      String :event, null: false
      column :object, :jsonb, null: false
      String :whodunnit
      DateTime :created_at, null: false

      index %i[item_type item_id]
      index :created_at
    end
  end
end
