require 'rails_helper'

RSpec.describe ExchangeRates::MonthlyExchangeRatesService do
  describe '.call' do
    subject(:call_service) { described_class.call }

    after do
      travel_back
    end

    # rubocop:disable all
    context 'when tomorrow is penultimate Thursday and today is Wednesday' do
      before do
        travel_to Time.zone.local(2023, 7, 19)
      end

      it 'calls the necessary services and notifies' do
        expect(ExchangeRates::UpdateCurrencyRatesService).to receive_message_chain(:new, :call)
        expect(ExchangeRates::UploadMonthlyFileService).to receive(:call).with(:csv)
        expect(ExchangeRates::UploadMonthlyFileService).to receive(:call).with(:xml)
        expect(SlackNotifierService).to receive(:call).with(/Exchange rates for the current month/)
        call_service
      end
    end

    context 'when tomorrow is not penultimate Thursday' do
      before do
        travel_to Time.zone.local(2023, 7, 12)
      end

      it 'does not call any services' do
        expect(ExchangeRates::UpdateCurrencyRatesService).not_to receive(:new)
        expect(ExchangeRates::UploadMonthlyFileService).not_to receive(:call)
        expect(SlackNotifierService).not_to receive(:call)
        call_service
      end
    end

    context 'when today is not Wednesday' do
      before do
        travel_to Time.zone.local(2023, 7, 18)
      end

      it 'does not call any services' do
        expect(ExchangeRates::UpdateCurrencyRatesService).not_to receive(:new)
        expect(ExchangeRates::UploadMonthlyFileService).not_to receive(:call)
        expect(SlackNotifierService).not_to receive(:call)
        call_service
      end
    end
    # rubocop:enable all
  end
end
