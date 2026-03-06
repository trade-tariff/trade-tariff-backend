module UkOnly
  extend ActiveSupport::Concern

  included do
    before_action :check_service

    def check_service
      if TradeTariffBackend.xi?
        raise ActionController::RoutingError, 'Invalid service'
      end
    end
  end
end
