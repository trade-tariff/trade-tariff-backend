module BatcherService
  class MyCommoditiesBatcherService
    def call(targets, user)
      raise ArgumentError, 'my commodities subscription must be present' unless user.my_commodities_subscription

      user_subscription = user.subscriptions_dataset.with_subscription_type(Subscriptions::Type.my_commodities).first
      metadata = user_subscription.metadata || {}
      metadata['commodity_codes'] = targets
      user_subscription.metadata = metadata
      user_subscription.save
      commodity_targets = GoodsNomenclature.where(goods_nomenclature_item_id: targets)

      user_subscription.add_targets(targets: commodity_targets, target_type: 'commodity')

      user_subscription.metadata
    end
  end
end
