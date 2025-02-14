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

    context 'when the year and month parameters are valid' do
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

    context 'when the year and month parameters are invalid' do
      let(:make_request) do
        get api_exchange_rate_path(
          '2023idadas-6',
          filter: { type: 'monthly' },
          format: :json,
        )
      end

      let(:pattern) do
        {
          error: 'not found',
          url: 'http://www.example.com/uk/api/v2/exchange_rates/2023idadas-6?filter%5Btype%5D=monthly',
        }
      end

      it { is_expected.to have_http_status(:not_found) }

      it { expect(response.body).to match_json_expression(pattern) }

      it { expect(ExchangeRates::ExchangeRateCollection).not_to have_received(:build) }
    end

    context 'when the type parameter is invalid' do
      let(:make_request) do
        get api_exchange_rate_path(
          '2023-6',
          filter: { type: 'invalid' },
          format: :json,
        )
      end

      let(:pattern) do
        {
          'error' => 'invalid',
          'url' => 'http://www.example.com/uk/api/v2/exchange_rates/2023-6?filter%5Btype%5D=invalid',
        }
      end

      it { is_expected.to have_http_status(:unprocessable_entity) }

      it { expect(response.body).to match_json_expression(pattern) }

      it { expect(ExchangeRates::ExchangeRateCollection).not_to have_received(:build) }
    end
  end
end
