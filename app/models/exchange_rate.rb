class ExchangeRate
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :id, :string
  attribute :rate, :float
  attribute :base_currency, :string
  attribute :applicable_date, :date

  def self.build_collection
    rates           = ExchangeRateService.new.call
    base_currency   = rates['base']
    applicable_date = rates['date']

    rates['rates'].map do |id, rate|
      new(
        id: id,
        rate: rate,
        base_currency: base_currency,
        applicable_date: applicable_date,
      )
    end
  end
end
