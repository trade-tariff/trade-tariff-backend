Sequel.migration do
  change do
    alter_table(:public__users) do
      add_column :deleted, TrueClass, default: false
    end
  end
end
