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

        def supplementary_measure_unit
          supplementary_measure&.supplementary_unit_duty_expression
        end

      private

        def filter_measures_by_geographical_area(unfiltered_measures)
          return unfiltered_measures if @geographical_area_id.blank?

          unfiltered_measures.select do |measure|
            measure.relevant_for_country? @geographical_area_id
          end
        end

        def supplementary_measure
          area_relevant_applicable_measures.find(&:supplementary?)
        end

        def area_relevant_applicable_measures
          @area_relevant_applicable_measures ||=
            applicable_measures.select do |measure|
              measure.relevant_for_country?(requested_geo_area_with_fallback)
            end
        end

        def requested_geo_area_with_fallback
          @geographical_area_id || GeographicalArea::ERGA_OMNES_ID
        end
      end
    end
  end
end
