class MonetaryExchangeRate < Sequel::Model
  plugin :oplog, primary_key: %i[monetary_exchange_period_sid
                                 child_monetary_unit_code]

  set_primary_key %i[monetary_exchange_period_sid child_monetary_unit_code]

  many_to_one :monetary_exchange_period, key: :monetary_exchange_period_sid,
                                  primary_key: :monetary_exchange_period_sid

  dataset_module do
    def currency(currency)
      filter(child_monetary_unit_code: currency)
    end
  end

  def self.latest(currency)
    currency(currency).exclude(operation_date: nil)
                      .order(:operation_date)
                      .last
                      .exchange_rate
  end
end
