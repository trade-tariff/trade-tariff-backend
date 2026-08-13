module Api
  module V2
    module Categorisation
      # Same behaviour as GreenLanes::GoodsNomenclaturesController, but reachable through
      # API Gateway under the tariff/categorisation OAuth scope instead of the legacy
      # static API key/token. The two routes run in parallel during the migration.
      class GoodsNomenclaturesController < GreenLanes::GoodsNomenclaturesController
        skip_before_action :authenticate
      end
    end
  end
end
