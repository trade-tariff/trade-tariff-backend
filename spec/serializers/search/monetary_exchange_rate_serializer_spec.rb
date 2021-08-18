describe Search::MonetaryExchangeRateSerializer do
  describe '#to_json' do
    let!(:gbp_unit) { create(:monetary_unit, monetary_unit_code: 'GBP', validity_start_date: Date.current.ago(10.years)) }
    let!(:eur_unit) { create(:monetary_unit, monetary_unit_code: 'EUR', validity_start_date: Date.current.ago(10.years)) }
    let!(:monetary_exchange_period) { create :monetary_exchange_period }
    let!(:monetary_exchange_rate) { create :monetary_exchange_rate, monetary_exchange_period_sid: monetary_exchange_period.monetary_exchange_period_sid }
    let(:pattern) do
      {
        child_monetary_unit_code: monetary_exchange_rate.child_monetary_unit_code,
        exchange_rate: monetary_exchange_rate.exchange_rate.to_s,
        operation_date: monetary_exchange_rate.operation_date.strftime('%Y-%m-%d'),
        validity_start_date: monetary_exchange_period.validity_start_date,
      }
    end

    it 'returns rendered monetary exchange rate entity as json' do
      expect(described_class.new(monetary_exchange_rate).to_json).to match_json_expression pattern
    end
  end
end
