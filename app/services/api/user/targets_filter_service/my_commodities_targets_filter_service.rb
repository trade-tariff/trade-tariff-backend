module Api
  module User
    module TargetsFilterService
      class MyCommoditiesTargetsFilterService
        attr_reader :subscription, :filter_type, :current_page, :per_page

        def initialize(subscription, filter_type, current_page, per_page)
          @subscription = subscription
          @filter_type = filter_type
          @current_page = current_page
          @per_page = per_page
        end

        def call
          return [subscription.subscription_targets.map, subscription.subscription_targets.size] if filter_type.blank?

          TimeMachine.now do
            service = Api::User::ActiveCommoditiesService.new(subscription)
            commodities, total =
              if service.respond_to?("#{filter_type}_commodities")
                service.public_send("#{filter_type}_commodities", page: current_page, per_page: per_page)
              else
                [[], 0]
              end
            targets = apply_commodities_to_subscription_targets(commodities)
            [targets, total]
          end
        end

        def apply_commodities_to_subscription_targets(commodities)
          commodities.map do |commodity|
            target = PublicUsers::SubscriptionTarget.new
            target.id = commodity.goods_nomenclature_item_id
            target.target_type = 'commodity'
            target.commodity = commodity
            target
          end
        end
      end
    end
  end
end
