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

          # How many source items the set holds now, which can be fewer than were
          # generated because operators can delete items. The controller works the counts
          # out for a whole page in one query and passes them in as params.
          attribute :atar_count do |gold_query_set, params|
            params.dig(:item_counts, gold_query_set.id, 'atar') || 0
          end

          attribute :synthetic_atar_count do |gold_query_set, params|
            params.dig(:item_counts, gold_query_set.id, 'synthetic_atar') || 0
          end
        end
      end
    end
  end
end
