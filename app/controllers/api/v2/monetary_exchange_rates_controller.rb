module Api
  module V2
    class MonetaryExchangeRatesController < ApiController
      def index
        jan_five_back = 5.years.ago.change({ day: 01, month: 01, hour: 0, minute: 0, second: 0 })
        @rates = MonetaryExchangeRate.eager(:monetary_exchange_period)
                                     .join_table(:inner, :monetary_exchange_periods, monetary_exchange_period_sid: :monetary_exchange_period_sid)
                                     .where(child_monetary_unit_code: 'GBP')
                                     .where { validity_start_date >= jan_five_back }
                                     .order(Sequel.asc(:validity_start_date))
                                     .all

        render json: Api::V2::MonetaryExchangeRateSerializer.new(@rates).serializable_hash
      end
    end
  end
end
