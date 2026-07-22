module Api
  module V2
    module Quotas
      class UtilizationSummarySerializer
        include JSONAPI::Serializer

        set_type :quota_utilization_summary
        set_id :id

        attributes :quota_order_number_id,
                   :quota_definition_sid,
                   :validity_start_date,
                   :validity_end_date,
                   :initial_volume,
                   :current_balance,
                   :volume_used,
                   :utilization_percentage,
                   :status,
                   :measurement_unit_code,
                   :quota_type
      end
    end
  end
end
