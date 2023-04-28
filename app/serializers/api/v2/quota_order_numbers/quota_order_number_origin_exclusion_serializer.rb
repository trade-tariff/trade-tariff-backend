module Api
  module V2
    module QuotaOrderNumbers
      class QuotaOrderNumberOriginExclusionSerializer
        include JSONAPI::Serializer

        set_type :quota_order_number_origin_exclusion

        set_id :id

        has_one :geographical_area, serializer: Api::V2::GeographicalAreaSerializer
      end
    end
  end
end
