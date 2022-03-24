module Api
  module V2
    module Measures
      class MeasureConditionPermutationSerializer
        include JSONAPI::Serializer

        set_type :measure_condition_permutation
        set_id   :id

        has_many :measure_conditions, serializer: Api::V2::Measures::MeasureConditionSerializer
      end
    end
  end
end
