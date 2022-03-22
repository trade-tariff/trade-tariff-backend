module Api
  module V2
    module Quotas
      class QuotaOrderNumberSerializer
        include JSONAPI::Serializer

        set_type :order_number

        set_id :quota_order_number_id

        attribute :number, &:quota_order_number_id

        has_many :geographical_areas, serializer: Api::V2::GeographicalAreaSerializer
      end
    end
  end
end
