Sequel.migration do
  change do
    alter_table(:public__users) do
      set_column_allow_null :external_id
    end
  end
end
