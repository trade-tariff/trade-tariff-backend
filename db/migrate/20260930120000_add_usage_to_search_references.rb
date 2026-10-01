Sequel.migration do
  up do
    alter_table :search_references do
      # 'search' references are used by public search and FPO training.
      # 'fpo' references are used only by FPO training and are hidden from public search.
      add_column :usage, String, null: false, default: 'search'
      add_constraint :search_references_usage_check, Sequel.lit("usage IN ('search', 'fpo')")
      add_index :usage
    end
  end

  down do
    alter_table :search_references do
      drop_index :usage
      drop_constraint :search_references_usage_check
      drop_column :usage
    end
  end
end
