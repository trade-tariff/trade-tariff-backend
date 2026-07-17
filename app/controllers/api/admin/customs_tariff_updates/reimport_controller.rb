module Api
  module Admin
    module CustomsTariffUpdates
      class ReimportController < BaseController
        def create
          worker = TradeTariffBackend.xi? ? XiCnReimportWorker : CustomsTariffReimportWorker
          worker.perform_async(customs_tariff_update.version)
          head :accepted
        end
      end
    end
  end
end
