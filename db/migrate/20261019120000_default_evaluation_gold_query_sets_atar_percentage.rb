Sequel.migration do
  up do
    alter_table(:evaluation_gold_query_sets) do
      set_column_default(:atar_percentage, 100)
    end
  end

  down do
    alter_table(:evaluation_gold_query_sets) do
      set_column_default(:atar_percentage, nil)
    end
  end
end
