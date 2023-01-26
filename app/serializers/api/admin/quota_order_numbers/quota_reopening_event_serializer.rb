module Api
  module Admin
    module QuotaOrderNumbers
      class QuotaReopeningEventSerializer
        include JSONAPI::Serializer

        set_id :quota_definition_sid

        set_type :quota_reopening_event

        attributes :reopening_date,
                   :event_type
      end
    end
  end
end
