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
                     :question_model,
                     :simulator_model,
                     :started_at,
                     :completed_at,
                     :total_cost_usd,
                     :total_provider_calls,
                     :total_latency_seconds,
                     :result_count,
                     :error_count,
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
        end
      end
    end
  end
end
