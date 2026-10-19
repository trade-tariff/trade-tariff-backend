Sequel.migration do
  change do
    alter_table(:tariff_knowledge_synthetic_atars) do
      add_column :source_workbook, String
      add_column :source_row, Integer
    end
  end
end
