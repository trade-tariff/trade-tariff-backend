Sequel.migration do
  change do
    alter_table(:evaluation_runs) do
      # One entry per persona value seen among this run's results (not a fixed enum — the backend
      # doesn't know trade-tariff-admin's EvaluationGoldQueryItem::PERSONAS labels, just groups by
      # whatever string is actually there), each a {result_count, gold_in_top1_count,
      # gold_in_top5_count, total_cost_usd, total_latency_seconds} hash — the same shape as this
      # run's own top-level aggregates, just scoped to one persona, so an operator can tell which
      # persona's accuracy/cost/latency is best or worst within a run.
      add_column :persona_breakdown, :jsonb, null: false, default: '{}'
    end
  end
end
