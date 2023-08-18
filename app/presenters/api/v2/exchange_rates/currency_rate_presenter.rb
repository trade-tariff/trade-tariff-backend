module Api
  module V2
    module ExchangeRates
      class CurrencyRatePresenter < WrapDelegator
        def initialize(currency_rate, month, year)
          super(currency_rate)

          @month = month
          @year = year
        end

        attr_reader :month, :year

        def id
          "#{year}-#{month}-#{currency_code}-currency-rate"
        end

        def exchange_rate_country_ids
          exchange_rate_countries.map(&:id)
        end
      end
    end
  end
end
