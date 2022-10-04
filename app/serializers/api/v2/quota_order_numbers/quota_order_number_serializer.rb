module Api
  module V2
    module QuotaOrderNumbers
      class QuotaOrderNumberSerializer
        include JSONAPI::Serializer

        set_type :quota_order_number

        set_id :quota_order_number_id

        attributes :quota_order_number_sid,
                   :validity_start_date,
                   :validity_end_date

        has_one :quota_definition, serializer: Api::V2::QuotaOrderNumbers::QuotaDefinitionSerializer
      end
    end
  end
end
