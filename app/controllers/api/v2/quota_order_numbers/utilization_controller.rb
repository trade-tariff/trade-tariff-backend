module Api
  module V2
    module QuotaOrderNumbers
      class UtilizationController < ApiController
        before_action :validate_order_number

        def show
          presenters = utilization_service.call
          raise Sequel::NoMatchingRow if presenters.nil?

          render json: Api::V2::QuotaOrderNumbers::UtilizationSerializer.new(
            presenters,
            meta: {
              quota_order_number_id: params[:quota_order_number_id],
              from_date: from_date.iso8601,
              to_date: to_date.iso8601,
            },
          ).serializable_hash
        end

      private

        def validate_order_number
          unless params[:quota_order_number_id].match?(/\A\d{6}\z/)
            raise ActionController::BadRequest, params[:quota_order_number_id]
          end
        end

        def utilization_service
          @utilization_service ||= QuotaUtilizationService.new(
            quota_order_number_id: params[:quota_order_number_id],
            from_date:,
            to_date:,
          )
        end

        def from_date
          @from_date ||= Date.parse(params[:from_date])
        rescue ArgumentError, TypeError
          Date.current.beginning_of_year
        end

        def to_date
          @to_date ||= Date.parse(params[:to_date])
        rescue ArgumentError, TypeError
          Date.current
        end
      end
    end
  end
end
