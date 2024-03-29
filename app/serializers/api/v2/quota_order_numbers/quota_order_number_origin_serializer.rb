module Api
  module V2
    module QuotaOrderNumbers
      class QuotaOrderNumberOriginSerializer
        include JSONAPI::Serializer

        set_type :quota_order_number_origin

        set_id :id

        attributes :validity_start_date,
                   :validity_end_date

        has_many :quota_order_number_origin_exclusions, serializer: Api::V2::QuotaOrderNumbers::QuotaOrderNumberOriginExclusionSerializer
        has_one :geographical_area, serializer: Api::V2::GeographicalAreaSerializer
      end
    end
  end
end
