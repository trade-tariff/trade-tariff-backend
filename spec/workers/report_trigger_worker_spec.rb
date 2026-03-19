RSpec.describe ReportTriggerWorker, type: :worker do
  subject(:worker) { described_class.new }

  describe '#perform' do
    before do
      allow(TradeTariffBackend).to receive(:service).and_return('uk')
      allow(Reporting::Commodities).to receive(:generate)
      worker.perform('commodities')
    end

    it { expect(Reporting::Commodities).to have_received(:generate) }
  end
end
