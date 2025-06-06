Sequel.migration do
  up do
    alter_table :green_lanes_update_notifications do
      add_foreign_key :theme_id, :green_lanes_themes, null: true, on_delete: :set_null
    end

  end

  down do
    alter_table :green_lanes_update_notifications do
      drop_foreign_key :theme_id
    end
  end
end
