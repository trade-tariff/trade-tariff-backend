Sequel.migration do
  change do
    alter_table :deltas do
      add_unique_constraint(
        %i[goods_nomenclature_sid delta_type delta_date],
        name: :deltas_upsert_unique
      )
    end
  end
end
