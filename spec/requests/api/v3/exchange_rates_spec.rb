require 'rails_helper'

RSpec.describe 'GET /uk/api/v3/exchange_rates', type: :request do
  let(:headers) { { 'Accept' => 'application/vnd.hmrc.3.0+json' } }

  before do
    allow(TradeTariffBackend).to receive(:uk?).and_return(true)
  end

  context 'with no params' do
    before do
      allow(ExchangeRates::PeriodList).to receive(:build).with('monthly', nil).and_return(
        instance_double(
          ExchangeRates::PeriodList,
          exchange_rate_periods: [],
        ),
      )
    end

    it 'returns 200' do
      get '/uk/api/v3/exchange_rates', headers: headers
      expect(response).to have_http_status(:ok)
    end

    it 'returns data and meta keys' do
      get '/uk/api/v3/exchange_rates', headers: headers
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body).to have_key(:data)
      expect(body[:meta][:total]).to eq(0)
    end
  end

  context 'with year and type params' do
    let(:period) do
      instance_double(
        ExchangeRates::Period,
        year: 2024,
        month: 1,
        has_exchange_rates: true,
      )
    end

    before do
      allow(ExchangeRates::PeriodList).to receive(:build).with('spot', 2024).and_return(
        instance_double(
          ExchangeRates::PeriodList,
          exchange_rate_periods: [period],
        ),
      )
    end

    it 'returns the matching periods' do
      get '/uk/api/v3/exchange_rates', params: { year: 2024, type: 'spot' }, headers: headers
      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body, symbolize_names: true)
      expect(body[:data].size).to eq(1)
      expect(body[:data].first[:year]).to eq(2024)
      expect(body[:data].first[:month]).to eq(1)
      expect(body[:meta][:total]).to eq(1)
    end
  end
end
