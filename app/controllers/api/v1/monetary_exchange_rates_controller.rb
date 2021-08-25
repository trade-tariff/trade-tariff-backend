module Api
  module V1
    class MonetaryExchangeRatesController < ApiController
      def index
        jan_five_back = 5.years.ago.change({ day: 01, month: 01, hour: 0, minute: 0, second: 0 })
        @rates = MonetaryExchangeRate.join_table(:inner, :monetary_exchange_periods, monetary_exchange_period_sid: :monetary_exchange_period_sid)
                                     .where(child_monetary_unit_code: 'GBP')
                                     .where { validity_start_date >= jan_five_back }
                                     .order(Sequel.asc(:validity_start_date))

        respond_to do |format|
          format.json {
            render 'api/v1/monetary_exchange_rates/index'
          }
        end
      end
    end
  end
end
