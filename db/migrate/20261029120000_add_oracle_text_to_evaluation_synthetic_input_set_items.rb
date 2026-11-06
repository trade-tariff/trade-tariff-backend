Sequel.migration do
  # Items created before this migration used the analyst description as their query.
  # Copying that query into oracle_text keeps those sets scoring exactly as before.
  up do
    alter_table(:evaluation_synthetic_input_set_items) do
      add_column :oracle_text, String
    end

    from(:evaluation_synthetic_input_set_items).update(oracle_text: :query)

    alter_table(:evaluation_synthetic_input_set_items) do
      set_column_not_null :oracle_text
    end
  end

  down do
    alter_table(:evaluation_synthetic_input_set_items) do
      drop_column :oracle_text
    end
  end
end
