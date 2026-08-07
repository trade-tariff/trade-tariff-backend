module Api
  module Admin
    module Search
      module Evaluation
        class ResultSerializer
          include JSONAPI::Serializer

          set_type :result
          set_id :id

          attributes :run_id,
                     :source_type,
                     :source_id,
                     :persona,
                     :expected_code,
                     :final_code,
                     :final_rank,
                     :gold_in_top1,
                     :gold_in_top5,
                     :latency_seconds,
                     :cost_usd,
                     :error,
                     :trace,
                     :created_at
        end
      end
    end
  end
end
