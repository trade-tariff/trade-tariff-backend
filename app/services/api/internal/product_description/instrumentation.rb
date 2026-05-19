module Api
  module Internal
    module ProductDescription
      module Instrumentation
        module_function

        def description_failed(error)
          ActiveSupport::Notifications.instrument(
            'description_failed.product_description',
            error_class: error.class.name,
            error_message: error.message,
          )
        end
      end
    end
  end
end
