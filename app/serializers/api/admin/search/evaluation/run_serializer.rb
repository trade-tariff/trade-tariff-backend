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
                     :created_at
        end
      end
    end
  end
end
