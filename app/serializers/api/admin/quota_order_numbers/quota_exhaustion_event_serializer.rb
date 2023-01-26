module Api
  module Admin
    module QuotaOrderNumbers
      class QuotaExhaustionEventSerializer
        include JSONAPI::Serializer

        set_id :quota_definition_sid

        set_type :quota_exhaustion_event

        attributes :exhaustion_date,
                   :event_type
      end
    end
  end
end
