module Api
  module V2
    module GreenLanes
      class MeasurePresenter < WrapDelegator
        def footnote_ids
          @footnote_ids = footnotes.map(&:code)
        end

        def goods_nomenclature_id
          @goods_nomenclature_id = goods_nomenclature.goods_nomenclature_sid
        end

        def exemptions
          []
        end

        def excluded_geographical_area_ids
          []
        end
      end
    end
  end
end
