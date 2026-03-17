RSpec.describe ScoreSelfTextBatchWorker, type: :worker do
  describe '#perform' do
    let(:scorer) { instance_double(SelfTextConfidenceScorer, score: nil) }

    before do
      allow(SelfTextConfidenceScorer).to receive(:new).and_return(scorer)
    end

    it 'scores the given SIDs with chapter_code' do
      described_class.new.perform([1, 2, 3], '44')

      expect(scorer).to have_received(:score).with([1, 2, 3], chapter_code: '44')
    end

    it 'scores without chapter_code when not provided' do
      described_class.new.perform([1, 2, 3])

      expect(scorer).to have_received(:score).with([1, 2, 3], chapter_code: nil)
    end

    it 'does nothing for empty SIDs' do
      described_class.new.perform([])

      expect(scorer).not_to have_received(:score)
    end
  end
end
