RSpec.describe Api::V2::MonetaryExchangeRatesController do
  routes { V2Api.routes }

  describe 'GET #index' do
    before do
      create(:monetary_unit, monetary_unit_code: 'GBP', validity_start_date: 10.years.ago.beginning_of_day)
      create(:monetary_unit, monetary_unit_code: 'EUR', validity_start_date: 10.years.ago.beginning_of_day)
    end

    context 'with two rates one today and one 5 years ago' do
      let(:monetary_exchange_period) { create :monetary_exchange_period }
      let!(:monetary_exchange_rate) { create(:monetary_exchange_rate, monetary_exchange_period_sid: monetary_exchange_period.monetary_exchange_period_sid) }

      let(:five_year_old_period) { create :monetary_exchange_period, validity_start_date: 5.years.ago.beginning_of_day }
      let!(:five_year_old_rate) { create :monetary_exchange_rate, monetary_exchange_period_sid: five_year_old_period.monetary_exchange_period_sid }

      it 'returns exchange rates for the last 5 years only', :aggregate_failures do
        get :index, format: :json

        json_response = JSON.parse(response.body)['data']
        expect(json_response.length).to eq(2)

        expect(json_response.first['attributes']['exchange_rate']).to eq(five_year_old_rate.exchange_rate.to_s)
        expect(json_response.last['attributes']['exchange_rate']).to eq(monetary_exchange_rate.exchange_rate.to_s)
      end
    end

    context 'with two rates one HKN and one 6 years ago' do
      before do
        create(:monetary_exchange_rate, child_monetary_unit_code: 'HKN')
        create(:monetary_exchange_rate, monetary_exchange_period: old_period)
      end

      let(:old_period) { create :monetary_exchange_period, :six_years_old }

      it "doesn't return either exchange rates" do
        get :index, format: :json

        json_response = JSON.parse(response.body)['data']
        expect(json_response.length).to eq(0)
      end
    end
  end
end
