module Api
  module Admin
    module QuotaOrderNumbers
      class QuotaDefinitionSerializer
        include JSONAPI::Serializer

        set_type :quota_definition

        set_id :quota_definition_sid

        attributes :validity_start_date,
                   :validity_end_date,
                   :initial_volume,
                   :quota_order_number_id,
                   :quota_type

        attribute :measurement_unit, &:formatted_measurement_unit

        has_many :quota_balance_events, serializer: Api::Admin::QuotaOrderNumbers::QuotaBalanceEventSerializer
        has_many :quota_order_number_origins, serializer: Api::Admin::QuotaOrderNumbers::QuotaOrderNumberOriginSerializer
      end
    end
  end
end
