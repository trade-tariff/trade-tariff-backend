module Api
  module Admin
    module QuotaOrderNumbers
      class QuotaUnsuspensionEventSerializer
        include JSONAPI::Serializer

        set_id :quota_definition_sid

        set_type :quota_unsuspension_event

        attributes :unsuspension_date,
                   :event_type
      end
    end
  end
end
