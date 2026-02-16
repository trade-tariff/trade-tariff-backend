RSpec.describe GenerateSelfTextReindexWorker, type: :worker do
  describe '#perform' do
    let(:search_client) { instance_double(TradeTariffBackend::SearchClient) }

    before do
      allow(TradeTariffBackend).to receive(:search_client).and_return(search_client)
      allow(search_client).to receive(:update)
      allow(SelfTextGenerator::Instrumentation).to receive(:reindex_started)
      allow(SelfTextGenerator::Instrumentation).to receive(:reindex_completed)
    end

    it 'updates the GoodsNomenclatureIndex' do
      described_class.new.perform

      expect(search_client).to have_received(:update) do |index|
        expect(index).to be_a(Search::GoodsNomenclatureIndex)
      end
    end

    it 'instruments reindex_started' do
      described_class.new.perform

      expect(SelfTextGenerator::Instrumentation).to have_received(:reindex_started)
    end

    it 'instruments reindex_completed' do
      described_class.new.perform

      expect(SelfTextGenerator::Instrumentation).to have_received(:reindex_completed)
    end
  end

  describe 'sidekiq options' do
    it 'uses the default queue' do
      expect(described_class.sidekiq_options['queue']).to eq(:default)
    end

    it 'disables retries' do
      expect(described_class.sidekiq_options['retry']).to be(false)
    end
  end
end
