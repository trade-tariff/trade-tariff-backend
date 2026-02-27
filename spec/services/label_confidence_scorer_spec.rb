RSpec.describe LabelConfidenceScorer do
  subject(:scorer) { described_class.new(embedding_service: embedding_service) }

  let(:embedding_service) { instance_double(EmbeddingService) }
  let(:embedding) { Array.new(1536) { 0.5 } }

  before do
    allow(embedding_service).to receive(:embed_batch) { |texts| Array.new(texts.size) { embedding } }
  end

  describe '#score' do
    it 'returns early for empty SID list' do
      scorer.score([])
      expect(embedding_service).not_to have_received(:embed_batch)
    end

    it 'returns early when no self-text embeddings exist' do
      label = create(:goods_nomenclature_label, description: 'Test label')

      scorer.score([label.goods_nomenclature_sid])

      expect(embedding_service).not_to have_received(:embed_batch)
    end

    context 'with a label and corresponding self-text embedding' do
      let(:commodity) do
        create(:commodity, :actual, :with_description,
               goods_nomenclature_item_id: '0101210000')
      end

      let(:label) do
        create(:goods_nomenclature_label,
               goods_nomenclature: commodity,
               description: 'Live horses for breeding',
               synonyms: Sequel.pg_array(%w[stallions mares], :text),
               colloquial_terms: Sequel.pg_array(['stud horses'], :text))
      end

      before do
        create(:goods_nomenclature_self_text,
               goods_nomenclature: commodity,
               self_text: 'Pure-bred breeding horses',
               embedding: "[#{embedding.join(',')}]")
        label
      end

      it 'scores the description' do
        scorer.score([label.goods_nomenclature_sid])

        label.reload
        expect(label.description_score).not_to be_nil
      end

      it 'scores each synonym at the matching index' do
        scorer.score([label.goods_nomenclature_sid])

        label.reload
        expect(label.synonym_scores.size).to eq(2)
        expect(label.synonym_scores).to all(be_a(Float))
      end

      it 'scores each colloquial term at the matching index' do
        scorer.score([label.goods_nomenclature_sid])

        label.reload
        expect(label.colloquial_term_scores.size).to eq(1)
        expect(label.colloquial_term_scores.first).to be_a(Float)
      end

      it 'embeds all terms in a single batch call' do
        scorer.score([label.goods_nomenclature_sid])

        # 1 description + 2 synonyms + 1 colloquial term = 4 texts
        expect(embedding_service).to have_received(:embed_batch).with(
          ['Live horses for breeding', 'stallions', 'mares', 'stud horses'],
        )
      end
    end

    context 'with empty label arrays' do
      let(:commodity) { create(:commodity, :actual, :with_description) }

      let(:label) do
        create(:goods_nomenclature_label,
               goods_nomenclature: commodity,
               description: 'A description',
               synonyms: Sequel.pg_array([], :text),
               colloquial_terms: Sequel.pg_array([], :text))
      end

      before do
        create(:goods_nomenclature_self_text,
               goods_nomenclature: commodity,
               self_text: 'Test',
               embedding: "[#{embedding.join(',')}]")
        label
      end

      it 'scores only the description' do
        scorer.score([label.goods_nomenclature_sid])

        label.reload
        expect(label.description_score).not_to be_nil
        expect(label.synonym_scores).to eq([])
        expect(label.colloquial_term_scores).to eq([])
      end
    end
  end
end
