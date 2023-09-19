module Api
  module V2
    module ExchangeRates
      class PeriodListsController < ApiController
        def show
          if serialized_period_list[:data].empty?
            render json: { data: {} }, status: :not_found
          else
            render json: serialized_period_list
          end
        end

        private

        def serialized_period_list
          ExchangeRates::ExchangeRatePeriodListSerializer.new(
            period_list,
            include: %i[exchange_rate_periods exchange_rate_years exchange_rate_periods.files],
          ).serializable_hash
        end

        def period_list
          @period_list ||= ::ExchangeRates::PeriodList.build(year, type)
        end

        def year
          (params[:year].presence || ExchangeRateCurrencyRate.max_year).to_i
        end

        def filter_params
          params.fetch(:filter, {}).permit(:type)
        end

        def type
          filter_params[:type]
        end

        def type
          type_param = filter_params[:type]

          type_param if [ExchangeRateCurrencyRate::SCHEDULED_RATE_TYPE, ExchangeRateCurrencyRate::SPOT_RATE_TYPE, ExchangeRateCurrencyRate::AVERAGE_RATE_TYPE].include?(type_param)
        end
      end
    end
  end
end
