RSpec.describe ReportTriggerWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe 'sidekiq configuration' do
    it 'uses the within_1_hour queue' do
      expect(described_class.get_sidekiq_options['queue']).to eq(:within_1_hour)
    end
  end

  describe '#perform' do
    before do
      allow(TradeTariffBackend).to receive(:service).and_return('uk')
      allow(Reporting::Commodities).to receive(:generate)
      worker.perform('commodities')
    end

    it { expect(Reporting::Commodities).to have_received(:generate) }
  end
end
