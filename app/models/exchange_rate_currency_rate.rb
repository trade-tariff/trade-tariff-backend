require 'csv'

class ExchangeRateCurrencyRate < Sequel::Model
  MONTHLY_RATE_TYPE = 'monthly'.freeze
  SPOT_RATE_TYPE = 'spot'.freeze
  AVERAGE_RATE_TYPE = 'average'.freeze

  RATES_FILE = 'data/exchange_rates/all_rates.csv'.freeze
  SPOT_RATES_FILE = 'data/exchange_rates/all_spot_rates.csv'.freeze

  one_to_many :exchange_rate_countries_currencies, key: :currency_code, primary_key: :currency_code, class_name: ExchangeRateCountryCurrency

  def_column_accessor :currency_description,
                      :country_description,
                      :country_code,
                      :applicable_date,
                      :year,
                      :month,
                      :country_currency_validity_start_date

  include ContentAddressableId

  content_addressable_fields :currency_code,
                             :country_code,
                             :validity_start_date,
                             :validity_end_date

  def presented_rate
    sprintf('%.4f', rate)
  end

  dataset_module do
    def with_applicable_date
      with(
        :exchange_rate_currency_rates,
        select_all(:exchange_rate_currency_rates)
        .select_append(
          Sequel.case(
            [
              [AVERAGE_RATE_TYPE, :validity_end_date],
            ],
            :validity_start_date,
            :rate_type,
          ).as(:applicable_date),
        ),
      ).from(:exchange_rate_currency_rates)
    end

    # Expands exchange rates to include:
    #
    # - The country code and description for the country
    # - The currency code and description for the currency
    #
    # This is done by joining the exchange_rate_countries_currencies table
    # and filtering by the descriptions and countries that are valid for the
    # exchange rate's validity period.
    #
    # We use infinity for country currency validity end dates that are null.
    # This will make the country currency descriptions apply for all dates that
    # start before the exchange rate's validity end date.
    def with_exchange_rate_country_currency
      association_right_join(:exchange_rate_countries_currencies)
        .select_append { Sequel[:exchange_rate_countries_currencies][:validity_start_date].as(:country_currency_validity_start_date) }
        .select_append { Sequel[:exchange_rate_countries_currencies][:validity_end_date].as(:country_currency_validity_end_date) }
        .select_append { Sequel[:exchange_rate_currency_rates][:validity_start_date].as(:validity_start_date) }
        .select_append { Sequel[:exchange_rate_currency_rates][:validity_end_date].as(:validity_end_date) }
        .where do |_query|
          (Sequel[:exchange_rate_countries_currencies][:validity_start_date] <= Sequel[:exchange_rate_currency_rates][:validity_end_date]) &
            (Sequel.function(:COALESCE, Sequel[:exchange_rate_countries_currencies][:validity_end_date], Sequel.lit("'infinity'")) >= Sequel[:exchange_rate_currency_rates][:validity_start_date])
        end
    end

    def with_applicable_year
      select { date_part('year', :applicable_date).cast(:integer).as(:year) }
    end

    def with_applicable_month_and_year
      select do
        [
          date_part('month', :applicable_date).cast(:integer).as(:month),
          date_part('year', :applicable_date).cast(:integer).as(:year),
        ]
      end
    end

    def by_type(type)
      where(rate_type: type)
    end

    def by_currency(currency_code)
      where(currency_code: currency_code.upcase)
    end

    def monthly_by_currency_last_year(currency_code, date)
      by_type(MONTHLY_RATE_TYPE)
        .by_currency(currency_code.upcase)
        .where('validity_start_date <= ?', date.end_of_month)
        .where('validity_end_date <= ?', date.end_of_month)
        .where('validity_start_date > ?', date.end_of_month - 12.months)
        .order_by(:validity_start_date)
    end

    def by_year(year)
      where(Sequel.cast(Sequel.function(:date_part, 'year', :applicable_date), Integer) => year)
    end

    def by_month_and_year(month, year)
      where(
        Sequel.cast(Sequel.function(:date_part, 'month', :applicable_date), Integer) => month,
        Sequel.cast(Sequel.function(:date_part, 'year', :applicable_date), Integer) => year,
      )
      .order(Sequel.desc(:applicable_date))
    end
  end

  class << self
    def all_years(type)
      with_applicable_date
        .distinct
        .by_type(type)
        .with_applicable_year
        .order(Sequel.desc(:year))
        .pluck(:year)
    end

    def max_year(type)
      with_applicable_date
        .order(Sequel.desc(:applicable_date))
        .by_type(type)
        .limit(1)
        .select_map(:applicable_date)
        .first
        &.year.presence || Time.zone.today.year
    end

    def months_for(type, year)
      scope = with_applicable_date
        .with_applicable_month_and_year
        .by_type(type)
        .order(Sequel.desc(:year), Sequel.desc(:month))
        .distinct

      scope = if year.present?
                scope.by_year(year)
              else
                scope
              end

      scope.pluck(:month, :year)
    end

    def for_month(month, year, type)
      with_applicable_date
        .by_month_and_year(month, year)
        .by_type(type)
        .with_exchange_rate_country_currency
        .all
        .group_by { |rate| [rate.currency_code, rate.country_code] }
        .map { |_, rates| rates.max_by(&:country_currency_validity_start_date) }
    end
  end
end
