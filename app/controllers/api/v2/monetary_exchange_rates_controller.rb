module Api
  module V2
    class MonetaryExchangeRatesController < ApiController
      def index
        render json: Api::V2::MonetaryExchangeRateSerializer.new(rates_last_five_years).serializable_hash
      end

      private

      def rates_last_five_years
        jan_five_years_ago = Time.zone.now.beginning_of_year - 5.years

        MonetaryExchangeRate.eager(:monetary_exchange_period)
                            .join_table(:inner, :monetary_exchange_periods, monetary_exchange_period_sid: :monetary_exchange_period_sid)
                            .where(child_monetary_unit_code: 'GBP')
                            .where { validity_start_date >= jan_five_years_ago }
                            .order(Sequel.asc(:validity_start_date))
                            .all
      end
    end
  end
end
