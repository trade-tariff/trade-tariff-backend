require 'rails_helper'

RSpec.describe Api::V2::ExchangeRatesController, type: :request do
  describe 'GET #show' do
    subject { make_request && response }

    let(:exchange_rate_collection) { build(:exchange_rates_collection, month: 6, year: 2023) }

    before do
      allow(ExchangeRates::ExchangeRateCollection)
        .to receive(:build)
        .with('6', '2023', 'monthly')
        .and_return(exchange_rate_collection)

      make_request
    end

    context 'when the year and month parameters are provided' do
      let(:make_request) do
        get api_exchange_rate_path(
          '2023-6',
          filter: { type: 'monthly' },
          format: :json,
        )
      end

      let(:pattern) do
        {
          data: {
            id: be_present,
            type: 'exchange_rate_collection',
            attributes: {
              year: 2023,
              month: 6,
              type: 'monthly',
            },
            relationships: {
              exchange_rate_files: Hash,
              exchange_rates: Hash,
            },
          },
        }.ignore_extra_keys!
      end

      it { is_expected.to have_http_status(:ok) }

      it { expect(response.body).to match_json_expression(pattern) }

      it { expect(ExchangeRates::ExchangeRateCollection).to have_received(:build).with('6', '2023', 'monthly') }
    end
  end
end
