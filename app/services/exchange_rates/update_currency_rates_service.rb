module ExchangeRates
  class UpdateCurrencyRatesService
    def initialize(date, sample_date, type)
      # Date is where the rates are taken from
      @date = date
      # Sample date is when the dates are published for
      @sample_date = sample_date
      @type = type
      @xe_api = ::ExchangeRates::XeApi.new(date: sample_date)
    end

    def call
      response = @xe_api.get_all_historic_rates

      ExchangeRateCurrencyRate.db.transaction do
        rates = build_rates(response)
        # This will only get rates for the current live rates so you cant pull historic data
        included_rates = @type == ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE ? ExchangeRateCountryCurrency.live_currency_codes : ExchangeRateCountryCurrency::SPOT_RATE_CURRENCY_CODES
        rates = rates.select { |rate| included_rates.include?(rate.currency_code) }

        upsert_rates(rates)
      end
    end

    private

    def build_rates(response)
      response['to'].map do |currency_data|
        build_rate(currency_data)
      end
    end

    def upsert_rates(rates)
      ExchangeRateCurrencyRate
        .dataset
        .insert_conflict(target: %i[currency_code validity_start_date validity_end_date rate_type])
        .multi_insert(rates)
    end

    def build_rate(currency_data)
      currency_code = currency_data['quotecurrency']
      rate = currency_data['mid']

      validity_start_date = @type == ExchangeRateCurrencyRate::MONTHLY_RATE_TYPE ? @date.beginning_of_month : @date.end_of_month
      validity_end_date = @date.end_of_month

      ExchangeRateCurrencyRate.new(
        currency_code:,
        validity_start_date:,
        validity_end_date:,
        rate:,
        rate_type: @type,
      )
    end
  end
end
