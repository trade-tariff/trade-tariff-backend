require 'csv'

class ExchangeRateCountry < Sequel::Model
  alias_method :id, :country_code
end
