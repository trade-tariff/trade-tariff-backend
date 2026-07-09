RSpec.describe MonetaryExchangeRate do
  describe '.latest' do
    let(:old_period) { create(:monetary_exchange_period, operation_date: 2.months.ago) }
    let(:latest_period) { create(:monetary_exchange_period, operation_date: 1.month.ago) }

    it 'returns the latest exchange rate for the currency', :aggregate_failures do
      create(:monetary_exchange_rate,
             child_monetary_unit_code: 'GBP',
             exchange_rate: 0.8,
             operation_date: old_period.operation_date,
             monetary_exchange_period: old_period)
      latest_rate = create(:monetary_exchange_rate,
                           child_monetary_unit_code: 'GBP',
                           exchange_rate: 0.9,
                           operation_date: latest_period.operation_date,
                           monetary_exchange_period: latest_period)
      create(:monetary_exchange_rate, child_monetary_unit_code: 'EUR', exchange_rate: 1.1)

      expect(described_class.currency('GBP').all).to contain_exactly(
        an_object_having_attributes(child_monetary_unit_code: 'GBP', exchange_rate: BigDecimal('0.8')),
        an_object_having_attributes(child_monetary_unit_code: 'GBP', exchange_rate: BigDecimal('0.9')),
      )
      expect(described_class.latest('GBP')).to eq(BigDecimal('0.9'))
      expect(latest_rate.monetary_exchange_period).to eq(latest_period)
    end
  end
end
