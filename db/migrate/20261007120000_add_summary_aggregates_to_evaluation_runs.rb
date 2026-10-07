Sequel.migration do
  change do
    alter_table(:evaluation_runs) do
      # How many results had the gold code in the top 1 / top 5 — reconciled the same way as
      # result_count/error_count already are, not computed live, so the run's own page never
      # needs to scan its results to show an accuracy figure.
      add_column :gold_in_top1_count, :integer, null: false, default: 0
      add_column :gold_in_top5_count, :integer, null: false, default: 0
      # Deliberately NOT foreign keys — these are advisory pointers an operator clicks through
      # from the run's summary to a specific result, not relational data whose integrity needs
      # enforcing, and a real FK here would be circular with evaluation_results.run_id's own FK
      # back the other way. Nil until reconciled, and nil forever on a run with no results, or
      # whose results all have a null cost/latency (e.g. every one errored before any usage was
      # recorded).
      add_column :max_cost_result_id, :integer
      add_column :min_cost_result_id, :integer
      add_column :max_latency_result_id, :integer
      add_column :min_latency_result_id, :integer
    end
  end
end
