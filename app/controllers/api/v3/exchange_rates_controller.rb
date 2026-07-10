module Api
  module V3
    class ExchangeRatesController < BaseController
      def index
        type = params.fetch(:type, 'monthly')
        year = params[:year].presence&.to_i

        period_list = ExchangeRates::PeriodList.build(type, year)
        periods = period_list.exchange_rate_periods

        render json: {
          data: periods.map do |period|
            {
              year: period.year,
              month: period.month,
              has_exchange_rates: period.has_exchange_rates,
            }
          end,
          meta: { total: periods.size },
        }
      end
    end
  end
end
