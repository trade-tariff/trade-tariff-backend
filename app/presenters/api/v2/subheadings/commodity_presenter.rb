module Api
  module V2
    module Subheadings
      class CommodityPresenter < SimpleDelegator
        class << self
          def wrap(commodities)
            commodities.map(&method(:new))
          end
        end

        def parent_sid
          ns_parent&.goods_nomenclature_sid if depth > 3
        end

        def overview_measures
          applicable_overview_measures.map do |measure|
            Api::V2::Measures::MeasurePresenter.new(measure, self)
          end
        end

        def overview_measure_ids
          applicable_overview_measures.map(&:measure_sid)
        end

        def leaf
          ns_leaf?
        end

        def declarable
          ns_declarable?
        end

        def number_indents
          ns_number_indents
        end
      end
    end
  end
end
