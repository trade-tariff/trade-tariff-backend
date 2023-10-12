class ExchangeRateCountryCurrency < Sequel::Model(:exchange_rate_countries_currencies)
  plugin :timestamps, update_on_create: true
  plugin :auto_validations, not_null: :presence

  def validate
    super

    validates_presence :country_description
    validates_presence :currency_description
    validates_presence :country_code
    validates_presence :currency_code
    validates_presence :validity_start_date
  end
end
