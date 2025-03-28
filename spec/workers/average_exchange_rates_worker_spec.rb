RSpec.describe AverageExchangeRatesWorker, type: :worker do
  subject(:perform) { described_class.new.perform }

  let(:today) { Time.zone.today.iso8601 }

  describe '#perform' do
    before do
      allow(ExchangeRates::CreateAverageExchangeRatesService).to receive(:call).with(force_run: false, selected_date: today).and_return(true)
      allow(SlackNotifierService).to receive(:call).and_call_original

      perform
    end

    it 'behaves as expected', :aggregate_failures do
      expect(ExchangeRates::CreateAverageExchangeRatesService).to have_received(:call).with(force_run: false, selected_date: today)
      expect(SlackNotifierService).to have_received(:call).with(match(/Average/))
    end
  end
end
