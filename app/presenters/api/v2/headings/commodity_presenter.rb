module Api
  module V2
    module Headings
      class CommodityPresenter < WrapDelegator
        def parent_sid
          if parent.is_a?(TenDigitGoodsNomenclature)
            parent.goods_nomenclature_sid
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
          leaf?
        end

        def declarable
          declarable?
        end
      end
    end
  end
end
