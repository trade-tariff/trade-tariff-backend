Sequel.migration do
  up do
    alter_table :myott_changes do
      add_unique_constraint(
        %i[goods_nomenclature_sid operation_date],
        name: :myott_changes_upsert_unique
      )
    end
  end

  down do
    alter_table :myott_changes do
      drop_constraint(:myott_changes_upsert_unique)
    end
  end
end