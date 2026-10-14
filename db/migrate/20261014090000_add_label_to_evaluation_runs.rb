Sequel.migration do
  change do
    alter_table(:evaluation_runs) do
      # A short, auto-generated description of what's distinctive about this run's own
      # configuration (AI-1437) -- normally three model-generated words, e.g. "vector based
      # retrieval", or the fixed "default settings" when the run has no overrides at all.
      # Nullable: generation runs in the background after the run is created and can fail, so
      # nothing may ever depend on this being present -- a run with label: nil simply displays
      # as "Run #123" with no suffix, same safe default already used for other recently-added
      # run fields.
      add_column :label, String
    end
  end
end
