module ExchangeRates
  class UpdateCurrencyRatesService
    def initialize
      @xe_api = XeApi.new
    end

    def call
      response = @xe_api.get_all_historic_rates

      ExchangeRateCurrencyRate.db.transaction do
        process_response(response)
      end
    end

    private

    def process_response(response)
      response['to'].each do |currency_data|
        create_rate(currency_data)
      end
    end

    def create_rate(currency_data)
      currency_code = currency_data['quotecurrency']
      rate_value = currency_data['mid']

      validity_start_date = Time.zone.today.beginning_of_month
      validity_end_date = Time.zone.today.end_of_month

      if ExchangeRateCurrency.where(currency_code:).any?
        ExchangeRateCurrencyRate.create(
          currency_code:,
          validity_start_date:,
          validity_end_date:,
          rate: rate_value,
          rate_type: 'scheduled',
        )
      end
    end
  end
end
