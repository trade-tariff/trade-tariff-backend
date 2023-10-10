require 'rails_helper'

RSpec.describe ExchangeRates::SpotExchangeRatesService do
  describe '.call' do
    subject(:call_service) { described_class.call }

    after do
      travel_back
    end

    context 'when today is March 31st' do
      before do
        travel_to Time.zone.local(2023, 3, 31)

        update_service = instance_double(ExchangeRates::UpdateCurrencyRatesService, call: true)

        allow(ExchangeRates::UpdateCurrencyRatesService).to receive(:new).and_return(update_service)
        allow(ExchangeRates::UploadMonthlyFileService).to receive(:call)
        allow(SlackNotifierService).to receive(:call)

        call_service
      end

      it 'calls UpdateCurrencyRatesService with SPOT_RATE_TYPE' do
        expect(ExchangeRates::UpdateCurrencyRatesService).to have_received(:new).with(type: ExchangeRateCurrencyRate::SPOT_RATE_TYPE)
      end

      it 'calls UploadMonthlyFileService with :spot_csv' do
        expect(ExchangeRates::UploadMonthlyFileService).to have_received(:call).with(:spot_csv)
      end

      it 'notifies about spot rates' do
        expect(SlackNotifierService).to have_received(:call).with(/Spot rates for the current month/)
      end
    end

    context 'when today is December 31st' do
      before do
        travel_to Time.zone.local(2023, 12, 31)

        update_service = instance_double(ExchangeRates::UpdateCurrencyRatesService, call: true)

        allow(ExchangeRates::UpdateCurrencyRatesService).to receive(:new).and_return(update_service)
        allow(ExchangeRates::UploadMonthlyFileService).to receive(:call)
        allow(SlackNotifierService).to receive(:call)

        call_service
      end

      it 'calls UpdateCurrencyRatesService with SPOT_RATE_TYPE' do
        expect(ExchangeRates::UpdateCurrencyRatesService).to have_received(:new).with(type: ExchangeRateCurrencyRate::SPOT_RATE_TYPE)
      end

      it 'calls UploadMonthlyFileService with :spot_csv' do
        expect(ExchangeRates::UploadMonthlyFileService).to have_received(:call).with(:spot_csv)
      end

      it 'notifies about spot rates' do
        expect(SlackNotifierService).to have_received(:call).with(/Spot rates for the current month/)
      end
    end

    context 'when today is not March 31st or December 31st' do
      before do
        travel_to Time.zone.local(2023, 7, 12)

        allow(ExchangeRates::UpdateCurrencyRatesService).to receive(:new)
        allow(ExchangeRates::UploadMonthlyFileService).to receive(:call)
        allow(SlackNotifierService).to receive(:call)

        call_service
      end

      it 'does not call UpdateCurrencyRatesService' do
        expect(ExchangeRates::UpdateCurrencyRatesService).not_to have_received(:new)
      end

      it 'does not call UploadMonthlyFileService' do
        expect(ExchangeRates::UploadMonthlyFileService).not_to have_received(:call)
      end

      it 'does not notify' do
        expect(SlackNotifierService).not_to have_received(:call)
      end
    end
  end
end
