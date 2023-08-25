require 'rails_helper'

RSpec.describe Api::V2::ExchangeRates::PeriodListsController, type: :request do
  describe 'GET #show' do
    subject { make_request && response }

    let(:period_list) { build(:period_list, :with_periods, :with_period_years, year: 2023) }

    before do
      allow(ExchangeRates::PeriodList).to receive(:build).with(2023).and_return(period_list)
      allow(ExchangeRateCurrencyRate).to receive(:max_year).and_return(2023)

      make_request
    end

    context 'when the year parameter is provided' do
      let(:make_request) { get api_exchange_rates_period_list_path(year: '2023', format: :json) }

      let(:pattern) do
        {
          data: {
            id: be_present,
            type: 'exchange_rate_period_list',
            attributes: {
              year: 2023,
            },
            relationships: {
              exchange_rate_periods: Hash,
              exchange_rate_years: Hash,
            },
          },
        }.ignore_extra_keys!
      end

      it { is_expected.to have_http_status(:ok) }
      it { expect(response.body).to match_json_expression(pattern) }
      it { expect(ExchangeRateCurrencyRate).not_to have_received(:max_year) }
    end

    context 'when the year parameter is not provided' do
      let(:make_request) { get api_exchange_rates_period_list_path(format: :json) }

      let(:pattern) do
        {
          data: {
            id: be_present,
            type: 'exchange_rate_period_list',
            attributes: {
              year: 2023,
            },
            relationships: {
              exchange_rate_periods: Hash,
              exchange_rate_years: Hash,
            },
          },
        }.ignore_extra_keys!
      end

      it { is_expected.to have_http_status(:ok) }
      it { expect(response.body).to match_json_expression(pattern) }
      it { expect(ExchangeRateCurrencyRate).to have_received(:max_year) }
    end
  end
end
