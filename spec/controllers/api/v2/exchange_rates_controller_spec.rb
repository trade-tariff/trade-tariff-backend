require 'rails_helper'

RSpec.describe Api::V2::ExchangeRatesController do
  describe 'GET #index' do
    subject(:response) { get :index }

    before do
      allow(ExchangeRateService).to receive(:new).and_return(service)
    end

    let(:service) { instance_double(ExchangeRateService, call: api_result) }

    let(:api_result) do
      {
        'rates' => {
          'CAD' => 1.5051,
        },
        'base' => 'EUR',
        'date' => '2021-03-11',
        'expires_at' => Time.zone.parse('2021-03-11T18:10:44Z'),
      }
    end

    let(:expected) do
      {
        'data' => [
          {
            'id' => 'CAD',
            'type' => 'exchange_rate',
            'attributes' => {
              'id' => 'CAD',
              'rate' => 1.5051,
              'base_currency' => 'EUR',
              'applicable_date' => '2021-03-11',
            },
          },
        ],
      }
    end

    it { expect(response['Cache-Control']).to eq('no-cache') }
    it { expect(JSON.parse(response.body)).to eq(expected) }
    it { expect(response).to have_http_status(:ok) }
  end
end
