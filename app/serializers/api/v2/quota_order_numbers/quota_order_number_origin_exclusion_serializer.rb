module Api
  module V2
    module QuotaOrderNumbers
      class QuotaOrderNumberOriginExclusionSerializer
        include JSONAPI::Serializer

        set_type :quota_order_number_origin_exclusion

        set_id :id

        attributes :excluded_geographical_area_sid, :quota_order_number_origin_sid
      end
    end
  end
end
