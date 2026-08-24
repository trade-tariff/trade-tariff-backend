Sequel.migration do
  change do
    alter_table(:evaluation_results) do
      # Rolled up into EvaluationRun.total_provider_calls by
      # EvaluationRun#reconcile_aggregates! (app/models/evaluation_run.rb).
      # Unlike cost_usd/latency_seconds (nullable — AI-1072's historical
      # import will have rows the old harness never recorded this for),
      # every new live row always knows this count, hence not null default 0.
      add_column :provider_calls, Integer, null: false, default: 0
    end
  end
end
