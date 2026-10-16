Sequel.migration do
  change do
    alter_table(:versions) do
      # Facts known only when the change happened, for example why ClearInvalidSearchReferences
      # removed a search reference. Nullable: older versions stay nil and are not backfilled
      # with a guess from the current tariff data. if_not_exists: this file was renamed from
      # 20261014150000, so databases that ran the old name already have the column.
      add_column :metadata, :jsonb, if_not_exists: true
    end
  end
end
