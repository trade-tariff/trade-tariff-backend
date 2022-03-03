module Api
  module V2
    module Measures
      class MeasureConditionPermutationGroupSerializer
        include JSONAPI::Serializer

        set_type :measure_condition_permutation_group
        set_id   :id

        attributes :condition_code
        has_many :permutations, serializer: Api::V2::Measures::MeasureConditionPermutationSerializer
      end
    end
  end
end
