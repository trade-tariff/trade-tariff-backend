module Api
  module V2
    module Measures
      class MeasureSearchResultSerializer
        include JSONAPI::Serializer

        set_type :measure

        set_id :measure_sid

        attributes :goods_nomenclature_item_id,
                   :measure_type_id,
                   :geographical_area_id,
                   :validity_start_date,
                   :validity_end_date,
                   :measure_generating_regulation_id,
                   :measure_generating_regulation_role,
                   :reduction_indicator,
                   :national,
                   :ordernumber

        attribute :measure_type_series_id do |measure|
          measure.measure_type&.measure_type_series_id
        end

        attribute :measure_type_description do |measure|
          measure.measure_type&.measure_type_description&.description
        end

        attribute :trade_movement_code do |measure|
          measure.measure_type&.trade_movement_code
        end

        attribute :geographical_area_description do |measure|
          measure.geographical_area&.geographical_area_description&.description
        end

        attribute :excluded_geographical_area_ids do |measure|
          measure.measure_excluded_geographical_areas.map(&:excluded_geographical_area)
        end

        attribute :has_geographical_exclusions do |measure|
          measure.measure_excluded_geographical_areas.any?
        end
      end
    end
  end
end
