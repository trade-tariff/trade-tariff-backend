module Api
  module User
    class GroupedMeasureCommodityChangeSerializer
      include JSONAPI::Serializer

      set_type :grouped_measure_commodity_change

      attributes :count

      belongs_to :commodity, record_type: :commodity, serializer: Api::User::SubscriptionTarget::CommoditySerializer, &:commodity
    end
  end
end
