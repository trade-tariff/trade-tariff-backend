# frozen_string_literal: true

module Api
  module V2
    module GreenLanes
      class ReferencedGoodsNomenclaturePresenter < WrapDelegator
        def initialize(goods_nomenclature, geographical_area_id = nil)
          super(goods_nomenclature)
          @geographical_area_id = geographical_area_id.presence
        end

        def parent_sid
          parent&.goods_nomenclature_sid
        end

        def measure_ids
          @measure_ids ||= measures.map(&:measure_sid)
        end

        def measures
          @measures ||=
            MeasurePresenter.wrap(filter_measures_by_geographical_area(super))
        end

      private

        def filter_measures_by_geographical_area(unfiltered_measures)
          return unfiltered_measures if @geographical_area_id.blank?

          unfiltered_measures.select do |measure|
            measure.relevant_for_country? @geographical_area_id
          end
        end
      end
    end
  end
end
