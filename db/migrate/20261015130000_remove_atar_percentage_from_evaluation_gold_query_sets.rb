Sequel.migration do
  up do
    alter_table(:evaluation_gold_query_sets) do
      drop_constraint(:evaluation_gold_query_sets_atar_percentage_check)
      drop_column(:atar_percentage)
    end
  end

  down do
    alter_table(:evaluation_gold_query_sets) do
      add_column(:atar_percentage, Integer, null: false, default: 100)
      add_constraint(:evaluation_gold_query_sets_atar_percentage_check, Sequel.lit('atar_percentage BETWEEN 0 AND 100'))
    end
  end
end
