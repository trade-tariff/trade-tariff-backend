module Api
  module Admin
    module CustomsTariffUpdates
      class BaseController < AdminController
        private

        def customs_tariff_update
          @customs_tariff_update ||= CustomsTariffUpdate
            .where(version: params[:customs_tariff_update_version])
            .first
            .tap { |u| raise Sequel::RecordNotFound unless u }
        end
      end
    end
  end
end
