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

          # Opt-in only (create passes with_items: true; index does not) -- the experiment
          # picker's list only ever reads name/id, so loading every set's items to populate a
          # field nothing reads would mean one extra query per set in the list, and a response
          # sized by every set's query text rather than by how many sets there are.
          attribute :items, if: ->(_set, params) { params[:with_items] } do |set|
            set.evaluation_synthetic_input_set_items.map do |item|
              { id: item.id, synthetic_atar_id: item.synthetic_atar_id, query: item.query, oracle_text: item.oracle_text, expected_code: item.expected_code }
            end
          end
        end
      end
    end
  end
end
