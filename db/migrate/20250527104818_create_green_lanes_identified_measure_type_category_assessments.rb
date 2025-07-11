# frozen_string_literal: true

Sequel.migration do
  up do
    create_table :green_lanes_identified_measure_type_category_assessments do
      primary_key :id
      String      :measure_type_id, size: 6, index: true, unique: true, null: false
      foreign_key :theme_id, :green_lanes_themes, null: false
      Time        :created_at, null: false
      Time        :updated_at, null: false
    end
  end

  down do
    alter_table :green_lanes_identified_measure_type_category_assessments do
      drop_foreign_key :theme_id
    end

    drop_table :green_lanes_identified_measure_type_category_assessments
  end
end
