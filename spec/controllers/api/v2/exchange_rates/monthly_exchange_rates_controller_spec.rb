require 'rails_helper'

RSpec.describe Api::V2::ExchangeRates::MonthlyExchangeRatesController, type: :request do
  describe 'GET #show' do
    subject(:rendered) { make_request && response }

    let(:rates_list) { build(:exchange_rates_list, month: 6, year: 2023) }

    before do
      allow(ExchangeRates::RatesList).to receive(:build).with(6, 2023).and_return(rates_list)

      make_request
    end

    context 'when the year and month parameters are provided' do
      let(:make_request) { get api_exchange_rates_monthly_exchange_rates_path(month: 6, year: 2023, format: :json) }

      let(:pattern) do
        {
          data: {
            id: '2023-6-exchange_rate_period',
            type: 'exchange_rates_list',
            attributes: {
              year: 2023,
              month: 6,
              publication_date: '2023-06-22T00:00:00.000Z',
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
      it { expect(ExchangeRates::RatesList).to have_received(:build).with(6, 2023) }
    end

    context 'when the year parameter is not provided' do
      let(:make_request) { get api_exchange_rates_monthly_exchange_rates_path(month: 6, format: :json) }

      let(:pattern) do
        { "errors": [{ "detail": 'not found' }] }
      end

      it { is_expected.to have_http_status(:not_found) }
      it { expect(response.body).to match_json_expression(pattern) }
      it { expect(ExchangeRates::RatesList).not_to have_received(:build).with(6, 2023) }
    end

    context 'when the month parameter is not provided' do
      let(:make_request) { get api_exchange_rates_monthly_exchange_rates_path(year: 2023, format: :json) }

      let(:pattern) do
        { "errors": [{ "detail": 'not found' }] }
      end

      it { is_expected.to have_http_status(:not_found) }
      it { expect(response.body).to match_json_expression(pattern) }
      it { expect(ExchangeRates::RatesList).not_to have_received(:build).with(6, 2023) }
    end
  end
end
