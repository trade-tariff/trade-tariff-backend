RSpec.describe SelfTextConfidenceScorer do
  subject(:scorer) { described_class.new(embedding_service: embedding_service) }

  let(:embedding_service) { instance_double(EmbeddingService) }
  let(:embedding) { Array.new(1536) { 0.5 } }

  before do
    allow(embedding_service).to receive(:embed_batch).and_return([embedding])
  end

  describe '#score' do
    it 'returns early for empty SID list' do
      scorer.score([])
      expect(embedding_service).not_to have_received(:embed_batch)
    end

    context 'with a record that has an EU reference' do
      let(:commodity) do
        create(:commodity, :actual, :with_description,
               goods_nomenclature_item_id: '0101210000')
      end

      let!(:record) do
        create(:goods_nomenclature_self_text,
               goods_nomenclature: commodity,
               self_text: 'Pure-bred breeding horses')
      end

      before do
        allow(SelfTextLookupService).to receive(:lookup)
          .with('0101210000')
          .and_return('Pure-bred breeding horses EU')
      end

      it 'populates the EU self-text from SelfTextLookupService' do
        scorer.score([record.goods_nomenclature_sid])

        record.reload
        expect(record.eu_self_text).to eq('Pure-bred breeding horses EU')
      end

      it 'generates embeddings for both texts' do
        allow(embedding_service).to receive(:embed_batch).and_return([embedding])

        scorer.score([record.goods_nomenclature_sid])

        # Called for: generated text embedding, EU text embedding
        expect(embedding_service).to have_received(:embed_batch).at_least(:twice)
      end

      it 'computes a similarity_score' do
        scorer.score([record.goods_nomenclature_sid])

        record.reload
        expect(record.similarity_score).not_to be_nil
      end
    end

    context 'with a non-declarable record that shares item_id with a commodity' do
      let(:subheading) do
        create(:goods_nomenclature,
               :actual,
               goods_nomenclature_item_id: '2710123100',
               producline_suffix: '10')
      end

      let(:commodity) do
        create(:goods_nomenclature,
               :actual,
               goods_nomenclature_item_id: '2710123100',
               producline_suffix: '80',
               parent: subheading)
      end

      let!(:record) do
        create(:goods_nomenclature_self_text,
               goods_nomenclature: subheading,
               self_text: 'Motor spirit for other purposes')
      end

      before do
        commodity
        allow(SelfTextLookupService).to receive(:lookup)
          .with('2710123100')
          .and_return('Aviation spirit')
      end

      it 'does not populate the EU self-text for the non-declarable node' do
        scorer.score([record.goods_nomenclature_sid])

        record.reload
        expect(record.eu_self_text).to be_nil
      end

      it 'does not compute similarity_score' do
        scorer.score([record.goods_nomenclature_sid])

        record.reload
        expect(record.similarity_score).to be_nil
      end
    end

    context 'with a record that has no EU reference (gap node)' do
      let!(:record) do
        create(:goods_nomenclature_self_text,
               goods_nomenclature_item_id: '9999990000',
               self_text: 'Other things not elsewhere specified',
               input_context: Sequel.pg_jsonb_wrap({
                 'ancestors' => [{ 'description' => 'Animals' }],
                 'description' => 'Other',
               }))
      end

      before do
        allow(SelfTextLookupService).to receive(:lookup)
          .with('9999990000')
          .and_return(nil)
      end

      it 'computes a coherence_score' do
        scorer.score([record.goods_nomenclature_sid])

        record.reload
        expect(record.coherence_score).not_to be_nil
      end

      it 'does not set similarity_score' do
        scorer.score([record.goods_nomenclature_sid])

        record.reload
        expect(record.similarity_score).to be_nil
      end
    end
  end
end
