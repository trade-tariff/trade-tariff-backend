require 'rails_helper'

RSpec.describe RecacheModelsWorker, type: :worker do
  describe '#perform' do
    let(:perform) { described_class.new.perform }

    before do
      create :footnote

      allow(BuildIndexPageWorker).to receive(:perform_async).and_call_original
      allow(TradeTariffBackend).to receive(:recache).and_call_original

      perform
    end

    it 'calls recache' do
      expect(TradeTariffBackend).to have_received(:recache)
    end

    it 'queues workers to build the index' do
      expect(BuildIndexPageWorker).to have_received(:perform_async)
    end
  end
end
