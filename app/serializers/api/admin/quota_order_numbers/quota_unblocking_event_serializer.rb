module Api
  module Admin
    module QuotaOrderNumbers
      class QuotaUnblockingEventSerializer
        include JSONAPI::Serializer

        set_id :quota_definition_sid

        set_type :quota_unblocking_event

        attributes :unblocking_date,
                   :event_type
      end
    end
  end
end
