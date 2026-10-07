module Api
  module Admin
    module Search
      module Evaluation
        class RunSerializer
          include JSONAPI::Serializer

          set_type :run
          set_id :id

          attributes :experiment_id,
                     :status,
                     :triggered_by,
                     :configuration_digest,
                     :effective_configuration,
                     :run_time_overrides,
                     :question_model,
                     :simulator_model,
                     :started_at,
                     :completed_at,
                     :total_cost_usd,
                     :total_provider_calls,
                     :total_latency_seconds,
                     :result_count,
                     :error_count,
                     :gold_in_top1_count,
                     :gold_in_top5_count,
                     :error_summary,
                     :aggregate_metrics,
                     :created_at,
                     :idempotency_key

          # Read from the run's experiment when the run is requested, so a run always
          # reports the set its experiment points at now. Known limitation, accepted:
          # if an experiment is pointed at a different set later, its old runs appear to
          # have used the new one.
          attribute :gold_query_set_id do |run|
            run.evaluation_experiment&.gold_query_set_id
          end

          # One small EvaluationResult[id] primary-key lookup per populated outlier — at most
          # four, each a single-row indexed fetch, only on show, never on index's list of many
          # runs. result.nil? is a genuine possibility to guard, not defensive paranoia:
          # reconcile_aggregates! could in principle run again after a result it pointed at was
          # somehow removed — nothing in this codebase deletes an individual EvaluationResult
          # today, but the lookup should degrade to nil rather than raise if that ever changes.
          OUTLIER_RESULT_FIELDS = %i[max_cost_result min_cost_result max_latency_result min_latency_result].freeze

          OUTLIER_RESULT_FIELDS.each do |field|
            attribute(field) do |run|
              result_id = run.public_send(:"#{field}_id")
              next nil if result_id.nil?

              result = EvaluationResult[result_id]
              next nil if result.nil?

              { id: result.id.to_s, source_type: result.source_type, source_id: result.source_id, cost_usd: result.cost_usd, latency_seconds: result.latency_seconds }
            end
          end
        end
      end
    end
  end
end
