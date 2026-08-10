module Api
  module V2
    module Categorisation
      # See GoodsNomenclaturesController — reachable via API Gateway (tariff/categorisation
      # scope) instead of the legacy static API key/token.
      class ThemesController < GreenLanes::ThemesController
        skip_before_action :authenticate
      end
    end
  end
end
