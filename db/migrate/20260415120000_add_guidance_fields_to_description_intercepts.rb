Sequel.migration do
  up do
    alter_table :description_intercepts do
      add_column :guidance_level, String
      add_column :guidance_location, String
      add_column :escalate_to_webchat, TrueClass, null: false, default: false
      add_column :filter_prefixes, 'text[]'
    end
  end

  down do
    alter_table :description_intercepts do
      drop_column :filter_prefixes
      drop_column :escalate_to_webchat
      drop_column :guidance_location
      drop_column :guidance_level
    end
  end
end
