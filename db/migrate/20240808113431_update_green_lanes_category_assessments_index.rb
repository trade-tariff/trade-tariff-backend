# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table :green_lanes_category_assessments do
      drop_index %i[measure_type_id regulation_id regulation_role]
      add_index %i[measure_type_id regulation_id regulation_role theme_id], unique: true
    end
  end

  down do
    alter_table :green_lanes_category_assessments do
      drop_index %i[measure_type_id regulation_id regulation_role theme_id]
      add_index %i[measure_type_id regulation_id regulation_role], unique: true
    end
  end
end
