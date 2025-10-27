module BatcherService
  class MyCommoditiesBatcherService
    def call(targets, user)
      raise ArgumentError, 'my commodities subscription must be present' unless user.my_commodities_subscription

      user_subscription = user.subscriptions_dataset.with_my_commodities_subscription.first
      user_subscription.metadata = targets
      user_subscription.save
      commodity_targets = GoodsNomenclature.where(goods_nomenclature_item_id: targets)

      PublicUsers::SubscriptionTarget.add_targets_for_subscription(
        subscription: user_subscription,
        targets: commodity_targets,
        target_type: 'commodity',
      )
      user_subscription.metadata
    end
  end
end
