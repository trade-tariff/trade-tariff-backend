module Api
  module Admin
    module CustomsTariffUpdates
      class StatusController < BaseController
        ALLOWED_STATUSES = %w[pending approved rejected].freeze

        def update
          new_status = status_params[:status]

          unless ALLOWED_STATUSES.include?(new_status)
            render json: { errors: [{ detail: "Status must be one of: #{ALLOWED_STATUSES.join(', ')}" }] },
                   status: :unprocessable_content
            return
          end

          if customs_tariff_update.status == new_status
            render json: { errors: [{ detail: "Status is already '#{new_status}'" }] },
                   status: :unprocessable_content
            return
          end

          previous_status = customs_tariff_update.status
          customs_tariff_update.update(status: new_status)
          CustomsTariffImporter::Instrumentation.status_changed(
            version: customs_tariff_update.version,
            from_status: previous_status,
            to_status: new_status,
            whodunnit: TradeTariffRequest.whodunnit,
          )

          render json: Api::Admin::CustomsTariffUpdateSerializer.new(customs_tariff_update, is_collection: false).serializable_hash
        end

        private

        def status_params
          params.require(:data).require(:attributes).permit(:status)
        end
      end
    end
  end
end
