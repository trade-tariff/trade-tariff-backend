module Api
  module V2
    module QuotaOrderNumbers
      class QuotaDefinitionSerializer
        include JSONAPI::Serializer

        set_type :quota_definition

        set_id :quota_definition_sid

        attributes :quota_order_number_id,
                   :validity_start_date,
                   :validity_end_date,
                   :initial_volume,
                   :measurement_unit_code,
                   :measurement_unit_qualifier_code,
                   :maximum_precision,
                   :critical_threshold

        has_many :measures, serializer: Api::V2::QuotaOrderNumbers::MeasureSerializer
      end
    end
  end
end
