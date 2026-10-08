# frozen_string_literal: true

Sequel.migration do
  # IMPORTANT! Data migrations up block should be idempotent (reruns of up should produce the same effect)
  # they may get re-run as part of data rollbacks but the rollback (down) function of the data migration will not get invoked

  up do
    next unless TradeTariffBackend.uk?

    # The accuracy/outlier columns Task 2 of AI-1068 added (gold_in_top1_count, gold_in_top5_count,
    # max_cost_result_id, min_cost_result_id, max_latency_result_id, min_latency_result_id) default to
    # 0/nil for every run that existed before that migration ran, and reconcile_aggregates! only runs
    # again when a new result is ingested or a run's status changes — neither of which happens for a
    # run that had already finished. Left alone, every pre-existing finished run would show "0% in top
    # 1, 0% in top 5" on its own summary page, rather than its real accuracy. reconcile_aggregates!
    # recomputes every aggregate from the run's own results, so re-running it here for every run is
    # naturally idempotent — a run reconciled since Task 2 shipped just gets the same values again.
    runs = EvaluationRun.all
    Rails.logger.info("Reconciling aggregates for #{runs.count} evaluation runs")

    runs.each(&:reconcile_aggregates!)
  end

  down do
    # Irreversible: reconcile_aggregates! only recomputes current aggregates from existing results,
    # it does not record what the six new columns' prior (default) values were.
  end
end
