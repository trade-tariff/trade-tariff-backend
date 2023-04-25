module Api
  module V2
    module QuotaOrderNumbers
      class QuotaOrderNumberOriginSerializer
        include JSONAPI::Serializer

        set_type :quota_order_number_origin

        set_id :quota_order_number_origin_sid

        attributes :validity_start_date,
                   :validity_end_date
      end
    end
  end
end
