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
                   :quota_type,
                   :critical_state,
                   :critical_threshold,
                   :formatted_measurement_unit

        has_one :measurement_unit, serializer: Api::Admin::QuotaOrderNumbers::MeasurementUnitSerializer
        has_one :quota_order_number, serializer: Api::Admin::QuotaOrderNumbers::QuotaOrderNumberSerializer
        has_many :quota_balance_events, serializer: Api::Admin::QuotaOrderNumbers::QuotaBalanceEventSerializer
        has_many :quota_order_number_origins, serializer: Api::Admin::QuotaOrderNumbers::QuotaOrderNumberOriginSerializer
        has_many :quota_unsuspension_events, serializer: Api::Admin::QuotaOrderNumbers::QuotaUnsuspensionEventSerializer
        has_many :quota_reopening_events, serializer: Api::Admin::QuotaOrderNumbers::QuotaReopeningEventSerializer
        has_many :quota_unblocking_events, serializer: Api::Admin::QuotaOrderNumbers::QuotaUnblockingEventSerializer
        has_many :quota_exhaustion_events, serializer: Api::Admin::QuotaOrderNumbers::QuotaExhaustionEventSerializer
        has_many :quota_critical_events, serializer: Api::Admin::QuotaOrderNumbers::QuotaCriticalEventSerializer
      end
    end
  end
end
