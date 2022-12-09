module Api
  module V2
    module Quotas
      class QuotaDefinitionSerializer
        include JSONAPI::Serializer

        set_type :definition

        set_id :quota_definition_sid

        attributes :quota_definition_sid,
                   :quota_order_number_id,
                   :initial_volume,
                   :validity_start_date,
                   :validity_end_date,
                   :status,
                   :description,
                   :balance

        attribute :measurement_unit, &:formatted_measurement_unit
        attribute :monetary_unit, &:monetary_unit_code
        attribute :measurement_unit_qualifier, &:measurement_unit_qualifier_code

        attribute :last_allocation_date do |definition|
          definition.last_balance_event&.last_import_date_in_allocation
        end

        attribute :suspension_period_start_date do |definition|
          definition.last_suspension_period.try(:suspension_start_date)
        end

        attribute :suspension_period_end_date do |definition|
          definition.last_suspension_period.try(:suspension_end_date)
        end

        attribute :blocking_period_start_date do |definition|
          definition.last_blocking_period.try(:blocking_start_date)
        end

        attribute :blocking_period_end_date do |definition|
          definition.last_blocking_period.try(:blocking_end_date)
        end

        has_one :incoming_quota_closed_and_transferred_event, serializer: Api::V2::Quotas::QuotaClosedAndTransferredEventSerializer, lazy_load_data: true
        has_one :quota_order_number, key: :order_number, record_type: :order_number, serializer: Api::V2::Quotas::QuotaOrderNumberSerializer, lazy_load_data: true
        has_many :measures, serializer: Api::V2::Shared::MeasureSerializer, lazy_load_data: true
        has_many :quota_balance_events, serializer: Api::V2::Quotas::QuotaBalanceEventSerializer, lazy_load_data: true
      end
    end
  end
end
