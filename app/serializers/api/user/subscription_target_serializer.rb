module Api
  module User
    class SubscriptionTargetSerializer
      include JSONAPI::Serializer

      belongs_to :target_object,
                 record_type: :commodity,
                 serializer: Api::User::SubscriptionTarget::CommoditySerializer do |target|
        target.commodity if target.commodity && !target.commodity.is_a?(PublicUsers::NullCommodity)
      end
    end
  end
end
