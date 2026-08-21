RSpec.describe AverageExchangeRatesWorker, type: :worker do
  subject(:perform) { described_class.new.perform }

  let(:today) { Time.zone.today.iso8601 }

  describe '#perform' do
    before do
      allow(ExchangeRates::CreateAverageExchangeRatesService).to receive(:call).with(force_run: false, selected_date: today).and_return(true)
      allow(SlackNotifierService).to receive(:call)
      perform
    end

    it 'calls CreateAverageExchangeRatesService' do
      expect(ExchangeRates::CreateAverageExchangeRatesService).to have_received(:call).with(force_run: false, selected_date: today)
    end

    it 'does not send a Slack notification' do
      expect(SlackNotifierService).not_to have_received(:call)
    end
  end
end
