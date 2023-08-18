Sequel.migration do
  up do
    alter_table(:search_suggestions) do
      drop_constraint(:search_suggestions_pkey, type: :primary_key)
      add_primary_key %i[id type]
    end
  end

  down do
    alter_table(:search_suggestions) do
      drop_constraint(:search_suggestions_pkey, type: :primary_key)
      add_primary_key %i[id value]
    end
  end
end
