# frozen_string_literal: true

module Api
  module V2
    module GreenLanes
      class ReferencedGoodsNomenclaturePresenter < WrapDelegator
        LICENCE_TYPE_CODES = %w[9 C L N].freeze

        def initialize(goods_nomenclature, geographical_area_id = nil)
          super(goods_nomenclature)
          @geographical_area_id = geographical_area_id.presence
        end

        def parent_sid
          parent&.goods_nomenclature_sid
        end

        def supplementary_measure_unit
          supplementary_measure&.supplementary_unit_duty_expression
        end

        def licences
          @licences ||=
            area_relevant_applicable_measures
              .flat_map(&:measure_conditions)
              .select { |mc| LICENCE_TYPE_CODES.include? mc.certificate_type_code }
              .map(&:certificate)
        end

        def licence_ids
          licences.map(&:id)
        end

      private

        def supplementary_measure
          area_relevant_applicable_measures.find(&:supplementary?)
        end

        def area_relevant_applicable_measures
          @area_relevant_applicable_measures ||=
            applicable_measures.select(&:import)
                               .select do |measure|
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
