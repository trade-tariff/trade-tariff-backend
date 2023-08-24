require 'rails_helper'

RSpec.describe Api::V2::ExchangeRates::MonthlyExchangeRatesController, type: :request do
  describe 'GET #show' do
    subject { make_request && response }

    let(:rates_list) { build(:exchange_rates_list, month: 6, year: 2023) }

    before do
      allow(ExchangeRates::MonthlyExchangeRate).to receive(:build).with('6', '2023').and_return(rates_list)

      make_request
    end

    context 'when the year and month parameters are provided' do
      let(:make_request) { get api_exchange_rates_monthly_exchange_rate_path('2023-6', format: :json) }

      let(:pattern) do
        {
          data: {
            id: be_present,
            type: 'monthly_exchange_rate',
            attributes: {
              year: 2023,
              month: 6,
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

      it { expect(ExchangeRates::MonthlyExchangeRate).to have_received(:build).with('6', '2023') }
    end
  end
end
