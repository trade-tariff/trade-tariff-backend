RSpec.describe ScoreLabelBatchWorker, type: :worker do
  describe '#perform' do
    let(:scorer) { instance_double(LabelConfidenceScorer, score: nil) }

    before do
      allow(GoodsNomenclatureSelfText).to receive(:regenerate_search_embeddings)
      allow(LabelConfidenceScorer).to receive(:new).and_return(scorer)
    end

    it 'regenerates search embeddings for the given SIDs' do
      described_class.new.perform([1, 2, 3])

      expect(GoodsNomenclatureSelfText).to have_received(:regenerate_search_embeddings).with([1, 2, 3])
    end

    it 'scores labels for the given SIDs' do
      described_class.new.perform([1, 2, 3])

      expect(scorer).to have_received(:score).with([1, 2, 3])
    end

    it 'does nothing for empty SIDs' do
      described_class.new.perform([])

      expect(GoodsNomenclatureSelfText).not_to have_received(:regenerate_search_embeddings)
      expect(scorer).not_to have_received(:score)
    end
  end
end
