module Api
  module Admin
    module QuotaOrderNumbers
      class QuotaCriticalEventSerializer
        include JSONAPI::Serializer

        set_id :quota_definition_sid

        set_type :quota_critical_event

        attributes :critical_state_change_date,
                   :event_type,
                   :critical_state
      end
    end
  end
end
