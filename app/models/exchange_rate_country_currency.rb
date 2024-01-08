class ExchangeRateCountryCurrency < Sequel::Model(:exchange_rate_countries_currencies)
  plugin :timestamps, update_on_create: true
  plugin :auto_validations, not_null: :presence

  SPOT_RATE_CURRENCY_CODES = %w[AUD CAD DKK EUR HKD JPY NOK ZAR SEK CHF USD].freeze

  def validate
    super

    validates_presence :country_description
    validates_presence :currency_description
    validates_presence :country_code
    validates_presence :currency_code
    validates_presence :validity_start_date
  end

  def self.live_currency_codes
    # Criteria:
    # Currency codes that are live in the current month

    where(
      (Sequel[:validity_end_date] =~ (Time.zone.today.beginning_of_month..Time.zone.today.end_of_month)) |
      (Sequel[:validity_end_date] =~ nil) &
      (Sequel[:validity_start_date] <= Time.zone.today.end_of_month),
    ).distinct(:currency_code).select_map(:currency_code)
  end

  def self.live_countries
    # Criteria:
    # ExchangeRateCountryCurrency objects that are live in the current month

    where(
      (Sequel[:validity_end_date] =~ (Time.zone.today.beginning_of_month..Time.zone.today.end_of_month)) |
      (Sequel[:validity_end_date] =~ nil) &
      (Sequel[:validity_start_date] <= Time.zone.today.end_of_month),
    ).order(:country_description)
  end
end
