module Api
  module Admin
    module GreenLanes
      class ThemesController < AdminController
        before_action :check_service, :authenticate_user!

        def index
          render json: serialize(themes.to_a)
        end

        private

        def themes
          @themes ||= ::GreenLanes::Theme.order(Sequel.asc(:section), Sequel.asc(:subsection))
        end

        def serialize(*args)
          Api::Admin::GreenLanes::ThemeSerializer.new(*args).serializable_hash
        end

        def check_service
          if TradeTariffBackend.uk?
            raise ActionController::RoutingError, 'Invalid service'
          end
        end
      end
    end
  end
end
