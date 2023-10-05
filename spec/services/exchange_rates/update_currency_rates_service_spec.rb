require 'rails_helper'

RSpec.describe ExchangeRates::UpdateCurrencyRatesService do
  describe '#call' do
    let(:xe_api) { instance_double(ExchangeRates::XeApi) }
    let(:service) { described_class.new }
    let(:response) do
      {
        'to' => [
          { 'quotecurrency' => 'AED', 'mid' => 4.662353708 }, # Has corresponding currency
          { 'quotecurrency' => 'AED', 'mid' => 4.662353708 }, # Has corresponding currency but is duplicated and won't create two
          { 'quotecurrency' => 'EUR', 'mid' => 6.662353708 }, # Has a corresponding currency
          { 'quotecurrency' => 'FGA', 'mid' => 5.662353708 }, # Has no corresponding currency
        ],
      }
    end

    let(:expected_rates) do
      [
        {
          currency_code: 'AED',
          validity_start_date: Time.zone.today.next_month.beginning_of_month,
          validity_end_date: Time.zone.today.next_month.end_of_month,
          rate: 4.662353708,
          rate_type: ExchangeRateCurrencyRate::SCHEDULED_RATE_TYPE,
        },
        {
          currency_code: 'EUR',
          validity_start_date: Time.zone.today.next_month.beginning_of_month,
          validity_end_date: Time.zone.today.next_month.end_of_month,
          rate: 6.662353708,
          rate_type: ExchangeRateCurrencyRate::SCHEDULED_RATE_TYPE,
        },
      ].as_json
    end

    before do
      allow(ExchangeRates::XeApi).to receive(:new).and_return(xe_api)
      allow(xe_api).to receive(:get_all_historic_rates).and_return(response)
      create(:exchange_rate_country_currency, currency_code: 'AED')
      create(:exchange_rate_country_currency, currency_code: 'EUR')
    end

    it 'only inserts rates that exist as currencies' do
      expect {
        service.call
      }.to change(ExchangeRateCurrencyRate, :count).by(2)
    end

    it 'creates the rates specified in the api' do
      service.call

      new_rates = ExchangeRateCurrencyRate.all.map(&:values).as_json

      expect(new_rates).to include_json(expected_rates)
    end
  end
end
