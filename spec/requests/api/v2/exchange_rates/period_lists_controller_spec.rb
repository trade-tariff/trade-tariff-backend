require 'rails_helper'

RSpec.describe Api::V2::ExchangeRates::PeriodListsController, type: :request do
  describe 'GET #show' do
    subject { make_request && response }

    let(:period_list) { build(:period_list, :with_periods, :with_period_years, year: 2023) }

    before do
      allow(ExchangeRates::PeriodList).to receive(:build).with('scheduled', year).and_return(period_list)

      make_request
    end

    context 'when the year parameter is provided' do
      before do
        allow(ExchangeRateCurrencyRate).to receive(:max_year).with('scheduled').and_return(2023)
      end

      let(:year) { 2023 }

      let(:make_request) do
        get api_exchange_rates_period_list_path(
          year: '2023',
          filter: { type: 'scheduled' },
          format: :json,
        )
      end

      let(:pattern) do
        {
          data: {
            id: be_present,
            type: 'exchange_rate_period_list',
            attributes: {
              year: 2023,
              type: 'scheduled',
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
      let(:year) { nil }

      let(:make_request) do
        get api_exchange_rates_period_list_path(
          filter: { type: 'scheduled' },
          format: :json,
        )
      end

      let(:pattern) do
        {
          data: {
            id: be_present,
            type: 'exchange_rate_period_list',
            attributes: {
              year: 2023,
              type: 'scheduled',
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
    end

    context 'when there are no available data for the year' do
      let(:year) { 1970 }
      let(:period_list) { [] }

      let(:make_request) do
        get api_exchange_rates_period_list_path(
          year: '1970',
          filter: { type: 'scheduled' },
          format: :json,
        )
      end

      it { is_expected.to have_http_status(:not_found) }
      it { expect(response.body).to match_json_expression({ data: {} }) }
    end
  end
end
