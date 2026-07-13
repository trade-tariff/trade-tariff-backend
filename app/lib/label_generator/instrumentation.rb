require 'active_support/notifications'

module LabelGenerator
  module Instrumentation
    extend GenerationEvents
    extend ScoringEvents

  module_function

    def instrument(event_name, payload = {}, &block)
      ActiveSupport::Notifications.instrument("#{event_name}.label_generator", payload, &block)
    end
  end
end
