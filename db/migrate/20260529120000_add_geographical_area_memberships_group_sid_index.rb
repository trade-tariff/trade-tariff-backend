Sequel.migration do
  up do
    add_index :geographical_area_memberships,
              %i[geographical_area_group_sid validity_start_date validity_end_date],
              name: :geo_area_memberships_group_sid_validity_index
  end

  down do
    drop_index :geographical_area_memberships,
               %i[geographical_area_group_sid validity_start_date validity_end_date],
               name: :geo_area_memberships_group_sid_validity_index
  end
end
