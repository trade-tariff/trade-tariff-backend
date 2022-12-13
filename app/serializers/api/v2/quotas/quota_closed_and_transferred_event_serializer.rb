module Api
  module V2
    module Quotas
      class QuotaClosedAndTransferredEventSerializer
        include JSONAPI::Serializer

        set_type :quota_closed_and_transferred_event

        attribute :closing_date

        attribute :transferred_amount do |event|
          event.transferred_amount.try(:to_f)
        end

        attribute :target_quota_definition_validity_start_date do |event|
          event.target_quota_definition.try(:validity_start_date)
        end

        attribute :target_quota_definition_validity_end_date do |event|
          event.target_quota_definition.try(:validity_end_date)
        end

        attribute :target_quota_definition_measurement_unit do |event|
          event.target_quota_definition.try(:formatted_measurement_unit)
        end

        attribute :quota_definition_validity_start_date do |event|
          event.quota_definition.try(:validity_start_date)
        end

        attribute :quota_definition_validity_end_date do |event|
          event.transferred_amount.try(:validity_start_date)
        end

        attribute :quota_definition_measurement_unit do |event|
          event.target_quota_definition.try(:formatted_measurement_unit)
        end
      end
    end
  end
end
