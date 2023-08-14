require 'rails_helper'

module ExchangeRates
  RSpec.describe UpdateCurrencyRatesService do
    describe '#call' do
      let(:xe_api) { instance_double(XeApi) }
      let(:service) { described_class.new }
      let(:response) do
        {
          'to' => [
            { 'quotecurrency' => 'AED', 'mid' => 4.662353708 },
          ],
        }
      end

      before do
        allow(XeApi).to receive(:new).and_return(xe_api)
        allow(xe_api).to receive(:get_all_historic_rates).and_return(response)
      end

      context 'when currency doesnt exist' do
        it 'doesnt create a new rate' do
          expect {
            service.call
          }.not_to change(ExchangeRateCurrencyRate, :count)
        end
      end

      context 'when currency exists' do
        before { create(:exchange_rate_currency) }

        it 'creates new rate' do
          expect {
            service.call
          }.to change(ExchangeRateCurrencyRate, :count).by(1)
        end

        # rubocop:disable RSpec/MultipleExpectations
        it 'raises unique index error when trying to create duplicate rates' do
          create(:exchange_rate_currency_rate)

          expect {
            expect {
              service.call
            }.to raise_error(Sequel::UniqueConstraintViolation)
          }.not_to change(ExchangeRateCurrencyRate, :count)
        end
        # rubocop:enable RSpec/MultipleExpectations
      end
    end
  end
end
