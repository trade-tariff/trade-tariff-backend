require 'rails_helper'

RSpec.describe ExchangeRates::MonthlyExchangeRatesService do
  describe '.call' do
    subject(:call_service) { described_class.call }

    after do
      travel_back
    end

    context 'when tomorrow is penultimate Thursday and today is Wednesday' do
      before do
        travel_to Time.zone.local(2023, 7, 19)

        update_service = instance_double(ExchangeRates::UpdateCurrencyRatesService, call: true)

        allow(ExchangeRates::UpdateCurrencyRatesService).to receive(:new).and_return(update_service)
        allow(ExchangeRates::UploadMonthlyFileService).to receive(:call)
        allow(SlackNotifierService).to receive(:call)

        call_service
      end

      it { expect(ExchangeRates::UpdateCurrencyRatesService).to have_received(:new) }
      it { expect(ExchangeRates::UploadMonthlyFileService).to have_received(:call).with(:csv) }
      it { expect(ExchangeRates::UploadMonthlyFileService).to have_received(:call).with(:xml) }
      it { expect(SlackNotifierService).to have_received(:call).with(/Exchange rates for the current month/) }
    end

    context 'when tomorrow is not penultimate Thursday' do
      before do
        travel_to Time.zone.local(2023, 7, 12)

        allow(ExchangeRates::UpdateCurrencyRatesService).to receive(:new)
        allow(ExchangeRates::UploadMonthlyFileService).to receive(:call)
        allow(SlackNotifierService).to receive(:call)

        call_service
      end

      it { expect(ExchangeRates::UpdateCurrencyRatesService).not_to have_received(:new) }
      it { expect(ExchangeRates::UploadMonthlyFileService).not_to have_received(:call) }
      it { expect(SlackNotifierService).not_to have_received(:call) }
    end
  end
end