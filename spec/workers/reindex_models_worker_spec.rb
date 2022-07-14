require 'rails_helper'

RSpec.describe ReindexModelsWorker, type: :worker do
  describe '#perform' do
    let(:perform) { described_class.new.perform }

    before do
      create :heading

      allow(BuildIndexPageWorker).to receive(:perform_async).and_call_original
      allow(TradeTariffBackend).to receive(:reindex).and_call_original
      allow(TradeTariffBackend).to receive(:v2_search_client).and_call_original

      perform
    end

    it 'calls reindex' do
      expect(TradeTariffBackend).to have_received(:reindex)
    end

    it 'calls v2_search_client to reindex' do
      expect(TradeTariffBackend).to have_received(:v2_search_client)
    end

    it 'queues workers to build the index' do
      expect(BuildIndexPageWorker).to have_received(:perform_async).twice
    end
  end
end
