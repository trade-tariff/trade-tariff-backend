require 'csv'

class ExchangeRateCurrencyRate < Sequel::Model
  SCHEDULED_RATE_TYPE = 'scheduled'.freeze
  SPOT_RATE_TYPE = 'spot'.freeze

  RATES_FILE = 'data/exchange_rates/all_rates.csv'.freeze
  SPOT_RATES_FILE = 'data/exchange_rates/all_spot_rates.csv'.freeze

  many_to_one :exchange_rate_currency, key: :currency_code, primary_key: :currency_code, class_name: ExchangeRateCurrency
  one_to_many :exchange_rate_countries, key: :currency_code, primary_key: :currency_code, class_name: ExchangeRateCountry

  def scheduled_rate?
    validity_end_date.present? && validity_start_date.day == 1 && validity_end_date == validity_start_date.end_of_month
  end

  def spot_rate?
    [3, 12].include?(validity_start_date.month) && validity_start_date.day == 31 && validity_end_date.nil?
  end

  dataset_module do
    def scheduled
      where(rate_type: SCHEDULED_RATE_TYPE)
    end

    def spot
      where(rate_type: SPOT_RATE_TYPE)
    end

    def by_year(year)
      return if year.blank?

      start_of_year = Time.zone.parse("#{year}-01-01").beginning_of_year
      end_of_year = start_of_year.end_of_year

      where { (validity_start_date >= start_of_year) & (validity_start_date <= end_of_year) }
        .order(Sequel.desc(:validity_start_date))
        .distinct(:validity_start_date)
    end

    def by_year_and_month(month, year = Time.zone.today.year)
      return if month.blank? || year.blank?

      start_of_month = Time.zone.parse("#{year}-#{month}-01").beginning_of_month
      end_of_month = start_of_month.end_of_month

      where { (validity_start_date >= start_of_month) & (validity_start_date <= end_of_month) }
        .order(Sequel.desc(:validity_start_date))
    end
  end

  class << self
    def populate(src = RATES_FILE)
      unrestrict_primary_key

      CSV.foreach(src) do |row|
        currency_code = row[0]
        validity_start_date = row[1]
        validity_end_date = row[2]
        rate = row[3]

        exchange_rate_currency_rate = new(currency_code:, validity_start_date:, validity_end_date:, rate:)
        exchange_rate_currency_rate.rate_type = determine_rate_type(exchange_rate_currency_rate)
        exchange_rate_currency_rate.save
      end

      restrict_primary_key
    end

    def all_years
      distinct
        .select { date_part('year', :validity_start_date).cast(:integer).as(:year) }
        .scheduled
        .order(Sequel.desc(:year))
        .pluck(:year)
    end

    def max_year
      order(Sequel.desc(:validity_start_date))
        .scheduled
        .limit(1)
        .select_map(:validity_start_date)
        .first
        &.year.presence || Time.zone.today.year
    end

    def months_for_year(year)
      by_year(year)
        .scheduled
        .select_map(:validity_start_date)
        .map(&:month)
        .uniq
    end

    def for_month(month, year = Time.zone.today.year)
      by_year_and_month(month, year)
        .scheduled
        .order(Sequel.asc(:validity_start_date))
        .order(Sequel.asc(:currency_code))
        .all
    end

    private

    def determine_rate_type(rate)
      return if rate.validity_start_date.blank?
      return 'scheduled' if rate.scheduled_rate?
      return 'spot' if rate.spot_rate?
    end
  end
end
