# frozen_string_literal: true

Sequel.migration do
  up do
    alter_table :geographical_area_description_periods do
      add_index :validity_start_date
      add_index :validity_end_date
    end
  end

  down do
    alter_table :geographical_area_description_periods do
      drop_index :validity_start_date
      drop_index :validity_end_date
    end
  end
end
