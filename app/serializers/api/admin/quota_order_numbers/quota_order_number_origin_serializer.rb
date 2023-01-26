module Api
  module Admin
    module QuotaOrderNumbers
      class QuotaOrderNumberOriginSerializer
        include JSONAPI::Serializer

        set_type :quota_order_number_origin

        set_id :quota_order_number_origin_sid

        attributes :geographical_area_id,
                   :geographical_area_description,
                   :validity_start_date,
                   :validity_end_date
      end
    end
  end
end
