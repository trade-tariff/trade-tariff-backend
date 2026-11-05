module Api
  module Admin
    module Search
      module Evaluation
        # One synthetic ATaR frozen into a set. query, oracle_text and expected_code are the copies taken
        # when the set was created, not the synthetic ATaR's current values.
        class SyntheticInputSetItemSerializer
          include JSONAPI::Serializer

          set_type :synthetic_input_set_item
          set_id :id

          attribute :synthetic_input_set_id, &:set_id

          attributes :synthetic_atar_id,
                     :query,
                     :oracle_text,
                     :expected_code
        end
      end
    end
  end
end
