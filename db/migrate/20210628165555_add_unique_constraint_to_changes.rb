Sequel.migration do
  up do
    alter_table :changes do
      add_unique_constraint(
        %i[goods_nomenclature_sid change_date],
        name: :changes_upsert_unique
      )
    end
  end

  down do
    alter_table :changes do
      drop_constraint(:changes_upsert_unique)
    end
  end
end
