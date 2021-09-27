RSpec.describe Api::V2::MonetaryExchangeRatesController, 'GET to #index' do
  context 'Expected results' do
    let!(:gbp_unit) { create(:monetary_unit, monetary_unit_code: 'GBP', validity_start_date: Date.current.ago(10.years)) }
    let!(:eur_unit) { create(:monetary_unit, monetary_unit_code: 'EUR', validity_start_date: Date.current.ago(10.years)) }
    let!(:monetary_exchange_period) { create :monetary_exchange_period }
    let!(:monetary_exchange_rate) { create :monetary_exchange_rate, monetary_exchange_period_sid: monetary_exchange_period.monetary_exchange_period_sid }

    let!(:five_year_old_period) { create :monetary_exchange_period, validity_start_date: Date.current.ago(5.years) }
    let!(:five_year_old_rate) { create :monetary_exchange_rate, monetary_exchange_period_sid: five_year_old_period.monetary_exchange_period_sid }

    it 'returns exchange rates for the last 5 years' do
      get :index, format: :json

      json_response = JSON.parse(response.body)['data']
      expect(json_response.length).to eq(2)

      er1 = json_response.first
      expect(er1['attributes']['exchange_rate']).to eq(five_year_old_rate.exchange_rate.to_s)

      er2 = json_response.last
      expect(er2['attributes']['exchange_rate']).to eq(monetary_exchange_rate.exchange_rate.to_s)
    end
  end

  context 'Constraints' do
    let!(:gbp_unit) { create :monetary_unit, monetary_unit_code: 'GBP', validity_start_date: Date.current - 10.years }
    let!(:eur_unit) { create :monetary_unit, monetary_unit_code: 'EUR', validity_start_date: Date.current - 10.years }
    let!(:monetary_exchange_period) { create :monetary_exchange_period }
    let!(:old_period) { create :monetary_exchange_period, :old }
    let!(:hkn_rate) { create :monetary_exchange_rate, child_monetary_unit_code: 'HKN' }
    let!(:old_rate) { create :monetary_exchange_rate, monetary_exchange_period: old_period }

    it "doesn't return exchange rates other than EUR/GBP" do
      get :index, format: :json

      json_response = JSON.parse(response.body)['data']
      expect(json_response.length).to eq(0)
    end

    it "doesn't return rates older than 5 years back" do
      get :index, format: :json

      json_response = JSON.parse(response.body)['data']
      expect(json_response.length).to eq(0)
    end
  end
end
