module XiOnly
  extend ActiveSupport::Concern

  included do
    before_action :check_service

    def check_service
      if TradeTariffBackend.uk?
        raise ActionController::RoutingError, 'Invalid service'
      end
    end
  end
end
