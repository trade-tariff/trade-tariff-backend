module Api
  module User
    class GroupedMeasureCommodityChangeSerializer
      include JSONAPI::Serializer

      set_type :grouped_measure_commodity_change

      attributes :count

      attribute :impacted_measures do |object, params|
        date = params[:date]
        object.measure_changes(date) if date
      end

      belongs_to :commodity, record_type: :commodity, serializer: Api::User::SubscriptionTarget::CommoditySerializer
      belongs_to :grouped_measure_change, record_type: :grouped_measure_change, serializer: Api::User::GroupedMeasureChangeSerializer, &:grouped_measure_change
    end
  end
end
