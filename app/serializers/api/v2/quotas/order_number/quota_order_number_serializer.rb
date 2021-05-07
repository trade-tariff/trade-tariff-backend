module Api
  module V2
    module Quotas
      module OrderNumber
        class QuotaOrderNumberSerializer
          include JSONAPI::Serializer

          set_type :order_number

          set_id :quota_order_number_id

          attribute :number do |quota|
            quota.quota_order_number_id
          end
          has_one :definition, serializer: Api::V2::Quotas::OrderNumber::QuotaDefinitionSerializer
        end
      end
    end
  end
end
