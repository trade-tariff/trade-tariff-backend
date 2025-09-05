module Subscriptions
  class Type < Sequel::Model(Sequel[:subscription_types].qualify(:public))
    STOP_PRESS = 'stop_press'.freeze
    COMMODITY_DELTA = 'commodity_delta'.freeze

    plugin :auto_validations
    plugin :timestamps, update_on_create: true

    one_to_many :subscriptions, class: 'PublicUsers::Subscription', key: :subscription_type_id

    def self.stop_press
      find(name: STOP_PRESS) || create(name: STOP_PRESS, description: 'Stop press email subscription for all stop presses, or particular chapters')
    end

    def self.commodity_delta
      find(name: COMMODITY_DELTA) || create(name: COMMODITY_DELTA, description: 'Commodity delta email subscription for changes in commodity details')
    end
  end
end
