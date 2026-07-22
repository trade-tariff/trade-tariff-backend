module Api
  module V2
    module QuotaOrderNumbers
      class UtilizationSerializer
        include JSONAPI::Serializer

        set_type :quota_utilization

        set_id :id

        attributes :quota_order_number_id,
                   :quota_definition_sid,
                   :validity_start_date,
                   :validity_end_date,
                   :status,
                   :measurement_unit_code,
                   :quota_type

        attribute(:initial_volume) { |r| r.initial_volume&.to_f }
        attribute(:current_balance) { |r| r.current_balance&.to_f }
        attribute(:volume_used) { |r| r.volume_used&.to_f }
        attribute(:utilization_percentage) { |r| r.utilization_percentage&.to_f }
        attribute(:balance_event_summary) do |r|
          r.balance_event_summary.map { |e| e.merge(new_balance: e[:new_balance]&.to_f) }
        end
      end
    end
  end
end
