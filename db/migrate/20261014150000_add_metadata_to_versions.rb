Sequel.migration do
  change do
    alter_table(:versions) do
      # Facts known only when the change happened, for example why ClearInvalidSearchReferences
      # removed a search reference. Nullable: older versions stay nil and are not backfilled
      # with a guess from the current tariff data.
      add_column :metadata, :jsonb
    end
  end
end
