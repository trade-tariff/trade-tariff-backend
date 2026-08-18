Sequel.migration do
  change do
    alter_table(:evaluation_runs) do
      # Stores the literal run_time_overrides the caller sent, verbatim — distinct from
      # effective_configuration/configuration_digest, which are DERIVED from this plus
      # the (mutable) experiment.configuration_overrides and the (mutable) admin-config
      # baseline. Idempotency-key replay detection must compare against something that
      # cannot drift between the original request and a retry; the derived columns can
      # drift if an operator edits the experiment or a baseline admin setting in between,
      # so they are unsafe for that comparison. This column can't drift, because nothing
      # ever updates it after creation.
      add_column :run_time_overrides, :jsonb, null: false, default: '{}'
    end
  end
end
