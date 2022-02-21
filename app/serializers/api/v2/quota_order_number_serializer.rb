module Api
  module V2
    class QuotaOrderNumberSerializer
      include JSONAPI::Serializer

      set_type :quota_order_number

      set_id :quota_order_number_sid

      attributes :quota_order_number_id,
                 :validity_start_date,
                 :validity_end_date

      has_one :quota_definition, serializer: Api::V2::QuotaDefinitionSerializer
    end
  end
end
