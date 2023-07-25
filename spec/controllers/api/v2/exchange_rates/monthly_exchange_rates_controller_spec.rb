require 'rails_helper'

RSpec.describe Api::V2::ExchangeRates::MonthlyExchangeRatesController, type: :request do
  describe 'GET #show' do
    subject(:rendered) { make_request && response }

    let(:rates_list) { build(:rates_list, month: 6, year: 2023) }

    before do
      allow(ExchangeRates::RatesList).to receive(:build).with(6, 2023).and_return(rates_list)
      allow(ExchangeRateCurrencyRate).to receive(:max_month).and_return(6)
      allow(ExchangeRateCurrencyRate).to receive(:max_year).and_return(2023)

      make_request
    end

    context 'when the year parameter is provided' do
      let(:make_request) { get api_exchange_rates_monthly_exchange_rates_path(month: '6', year: '2023', format: :json) }

      let(:pattern) do
        {
          data: {
            id: '2023-06-exchange_rate_period',
            type: 'exchange_rate_period',
            attributes: {
              year: 2023,
              month: 6,
              publication_date: "2023-06-22T00:00:00.000Z",
            },
            relationships: {
              files: Hash,
              exchange_rates: Hash,
            },
          },
        }.ignore_extra_keys!
      end

      it { is_expected.to have_http_status(:ok) }
      it { expect(response.body).to match_json_expression(pattern) }
      it { expect(ExchangeRateCurrencyRate).not_to have_received(:max_year) }
    end

    # context 'when the year parameter is not provided' do
    #   let(:make_request) { get api_exchange_rates_monthly_exchange_rates_path(format: :json) }

    #   let(:pattern) do
    #     {
    #       data: {
    #         id: '2023-06-exchange_rate_period',
    #         type: 'exchange_rate_period',
    #         attributes: {
    #           year: 2023,
    #           month: 6,
    #           publication_date: "2023-06-22T00:00:00.000Z",
    #         },
    #         relationships: {
    #           files: Hash,
    #           exchange_rates: Hash,
    #         },
    #       },
    #     }.ignore_extra_keys!
    #   end

    #   it { is_expected.to have_http_status(:ok) }
    #   it { expect(response.body).to match_json_expression(pattern) }
    #   it { expect(ExchangeRateCurrencyRate).to have_received(:max_year) }
    # end
  end
end
