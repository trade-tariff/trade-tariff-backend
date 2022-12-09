module Api
  module V2
    module Quotas
      class QuotaClosedAndTransferredEventSerializer
        include JSONAPI::Serializer

        set_type :quota_closed_and_transferred_event

        attributes :quota_definition_sid,
                   :closing_date

        attribute :transferred_amount do |event|
          event.transferred_amount.try(:to_f)
        end

        has_one :quota_definition, serializer: Api::V2::QuotaOrderNumbers::QuotaDefinitionSerializer
      end
    end
  end
end
