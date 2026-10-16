module Api
  module Admin
    module Search
      module Evaluation
        class SyntheticInputSetSerializer
          include JSONAPI::Serializer

          set_type :synthetic_input_set
          set_id :id

          attributes :name,
                     :requested_size,
                     :actual_size,
                     :created_by,
                     :created_at

          attribute :items do |set|
            set.evaluation_synthetic_input_set_items.map do |item|
              { id: item.id, synthetic_atar_id: item.synthetic_atar_id, query: item.query, expected_code: item.expected_code }
            end
          end
        end
      end
    end
  end
end
