module Api
  module V2
    module Quotas
      module OrderNumber
        class QuotaOrderNumberSerializer
          include JSONAPI::Serializer

          set_type :order_number

          set_id :quota_order_number_id

          attribute :number, &:quota_order_number_id
          has_one :definition, serializer: Api::V2::Quotas::OrderNumber::QuotaDefinitionSerializer
        end
      end
    end
  end
end
