module Api
  module Admin
    module Search
      module Evaluation
        class GoldQuerySetSerializer
          include JSONAPI::Serializer

          set_type :gold_query_set
          set_id :id

          attributes :name,
                     :requested_size,
                     :atar_percentage,
                     :planned_count,
                     :generated_count,
                     :failed_count,
                     :status,
                     :failures,
                     :created_by,
                     :created_at
        end
      end
    end
  end
end
