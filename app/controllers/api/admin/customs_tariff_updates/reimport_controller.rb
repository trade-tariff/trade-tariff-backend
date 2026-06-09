module Api
  module Admin
    module CustomsTariffUpdates
      class ReimportController < BaseController
        def create
          # No status guard — reimport is a recovery tool that must work on any update status
          CustomsTariffReimportWorker.perform_async(customs_tariff_update.version)
          head :accepted
        end
      end
    end
  end
end
