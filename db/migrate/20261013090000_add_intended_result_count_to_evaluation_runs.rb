Sequel.migration do
  change do
    alter_table(:evaluation_runs) do
      # The gold query set's size at the exact moment this run started, snapshotted once so
      # it can never drift if the set is edited afterward (AI-1435). Nullable: a run created
      # before this column existed has no way to know its own launch-time value after the
      # fact, and simply stays nil forever rather than being backfilled with a guess.
      add_column :intended_result_count, :integer
    end
  end
end
