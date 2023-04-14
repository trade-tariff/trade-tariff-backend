module Api
  module V2
    module Headings
      class CommodityPresenter < SimpleDelegator
        class << self
          def wrap(commodities)
            commodities.map(&method(:new))
          end
        end

        def parent_sid
          if ns_parent.is_a?(Commodity) || ns_parent.is_a?(Subheading)
            ns_parent.goods_nomenclature_sid
          end
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
      end
    end
  end
end
