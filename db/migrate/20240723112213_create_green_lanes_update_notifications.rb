# frozen_string_literal: true

Sequel.migration do
  change do
    create_table :green_lanes_update_notifications do
      primary_key :id
      String      :measure_type_id, size: 6, null: false
      String      :regulation_id, size: 255, null: true
      Int         :regulation_role, null: true
      Int         :status, null: false
      Time        :created_at, null: false
      Time        :updated_at, null: false

    end
  end
end
