RSpec.describe AverageExchangeRatesWorker, type: :worker do
  subject(:perform) { described_class.new.perform }

  describe '#perform' do
    before do
      allow(ExchangeRates::AverageExchangeRatesService).to receive(:call).with(false).and_return(true)
      allow(SlackNotifierService).to receive(:call).and_call_original

      perform
    end

    it 'will behave as expected', :aggregate_failures do
      expect(ExchangeRates::AverageExchangeRatesService).to have_received(:call).with(false)
      expect(SlackNotifierService).to have_received(:call).with(match(/Average/))
    end
  end
end
