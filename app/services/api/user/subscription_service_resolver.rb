module Api
  module User
    # Chooses the batcher and the targets filter for a subscription type.
    # This lives outside the models pack because it names the service classes.
    class SubscriptionServiceResolver
      class UnsupportedBatcherError < StandardError; end
      class UnsupportedFilterError < StandardError; end

      class << self
        def batcher_for(subscription)
          if subscription.subscription_type == Subscriptions::Type.my_commodities
            Api::User::BatcherService::MyCommoditiesBatcherService
          else
            raise UnsupportedBatcherError, "Unsupported subscription type for batching: #{subscription.subscription_type.name}"
          end
        end

        def filter_for(subscription)
          if subscription.subscription_type == Subscriptions::Type.my_commodities
            Api::User::TargetsFilterService::MyCommoditiesTargetsFilterService.new(subscription)
          else
            raise UnsupportedFilterError, "Unsupported subscription type for targets filtering: #{subscription.subscription_type.name}"
          end
        end
      end
    end
  end
end
