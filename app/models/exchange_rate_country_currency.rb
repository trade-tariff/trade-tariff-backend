class ExchangeRateCountryCurrency < Sequel::Model(:exchange_rate_countries_currencies)
  plugin :timestamps, update_on_create: true
  plugin :auto_validations, not_null: :presence
  plugin :dirty

  def validate
    super

    validates_presence :country_description
    validates_presence :currency_description
    validates_presence :country_code
    validates_presence :currency_code
    validates_presence :validity_start_date
  end

  dataset_module do
    def between(period_start_date, period_end_date)
      where do |_query|
        (Sequel[:exchange_rate_countries_currencies][:validity_start_date] <= period_start_date) &
          (Sequel.function(:COALESCE, Sequel[:exchange_rate_countries_currencies][:validity_end_date], Sequel.lit("'infinity'")) >= period_end_date)
      end
    end
  end
end
