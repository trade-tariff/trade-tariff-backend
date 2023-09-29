require 'csv'

class ExchangeRateCurrencyRate < Sequel::Model
  SCHEDULED_RATE_TYPE = 'scheduled'.freeze
  SPOT_RATE_TYPE = 'spot'.freeze
  AVERAGE_RATE_TYPE = 'average'.freeze

  RATES_FILE = 'data/exchange_rates/all_rates.csv'.freeze
  SPOT_RATES_FILE = 'data/exchange_rates/all_spot_rates.csv'.freeze

  many_to_one :exchange_rate_currency, key: :currency_code, primary_key: :currency_code, class_name: ExchangeRateCurrency
  one_to_many :exchange_rate_countries, key: :currency_code, primary_key: :currency_code, class_name: ExchangeRateCountry

  delegate :currency_description,
           to: :exchange_rate_currency,
           allow_nil: true

  def_column_accessor :country, :country_code, :applicable_date, :year, :month

  include ContentAddressableId

  content_addressable_fields :currency_code, :validity_start_date, :validity_end_date, :country, :country_code

  def presented_rate
    sprintf('%.4f', rate)
  end

  def period_year
    validity_start_date.year
  end

  def period_month
    validity_start_date.month
  end

  def scheduled_rate?
    validity_end_date.present? &&
      validity_start_date.present? &&
      validity_start_date.day == 1 &&
      validity_end_date == validity_start_date.end_of_month
  end

  dataset_module do
    def with_applicable_date
      with(
        :cte,
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
      ).from(:cte)
    end

    def with_applicable_year
      select { date_part('year', :applicable_date).cast(:integer).as(:year) }
    end

    def with_applicable_month
      select { date_part('month', :applicable_date).cast(:integer).as(:month) }
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
        .order(Sequel.asc(:applicable_date))
        .order(Sequel.asc(:currency_code))
        .all
    end
  end
end
