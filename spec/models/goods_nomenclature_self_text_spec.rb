RSpec.describe GoodsNomenclatureSelfText do
  subject(:self_text) { build(:goods_nomenclature_self_text) }

  describe 'validations' do
    it { is_expected.to be_valid }

    it 'requires goods_nomenclature_item_id' do
      self_text.goods_nomenclature_item_id = nil
      expect(self_text).not_to be_valid
    end

    it 'requires self_text' do
      self_text.self_text = nil
      expect(self_text).not_to be_valid
    end

    it 'requires generation_type' do
      self_text.generation_type = nil
      expect(self_text).not_to be_valid
    end

    it 'requires context_hash' do
      self_text.context_hash = nil
      expect(self_text).not_to be_valid
    end

    it 'requires generated_at' do
      self_text.generated_at = nil
      expect(self_text).not_to be_valid
    end

    it 'validates generation_type inclusion' do
      self_text.generation_type = 'unknown'
      expect(self_text).not_to be_valid
      expect(self_text.errors[:generation_type]).to be_present
    end

    it 'accepts mechanical generation_type' do
      self_text.generation_type = 'mechanical'
      expect(self_text).to be_valid
    end

    it 'accepts ai generation_type' do
      self_text.generation_type = 'ai'
      expect(self_text).to be_valid
    end

    it 'accepts ai_non_other generation_type' do
      self_text.generation_type = 'ai_non_other'
      expect(self_text).to be_valid
    end
  end

  describe '.lookup' do
    it 'returns self_text string when record exists' do
      record = create(:goods_nomenclature_self_text, self_text: 'Covers widgets')
      expect(described_class.lookup(record.goods_nomenclature_sid)).to eq('Covers widgets')
    end

    it 'returns nil when record does not exist' do
      expect(described_class.lookup(-1)).to be_nil
    end
  end

  describe '.stale' do
    it 'returns only stale records' do
      stale_record = create(:goods_nomenclature_self_text, :stale)
      create(:goods_nomenclature_self_text)

      expect(described_class.stale.all).to eq([stale_record])
    end
  end

  describe '.needs_review' do
    it 'returns only records needing review' do
      review_record = create(:goods_nomenclature_self_text, :needs_review)
      create(:goods_nomenclature_self_text)

      expect(described_class.needs_review.all).to eq([review_record])
    end
  end

  describe '#mark_stale!' do
    it 'sets stale to true' do
      record = create(:goods_nomenclature_self_text, stale: false)
      record.mark_stale!

      expect(record.reload.stale).to be true
    end
  end

  describe '.regenerate_search_embeddings' do
    let(:embedding_service) { instance_double(EmbeddingService) }

    before do
      allow(EmbeddingService).to receive(:new).and_return(embedding_service)
      allow(embedding_service).to receive(:embed_batch) { |texts| texts.map { Array.new(1536, 0.0) } }
    end

    it 'updates search_text and search_embedding for records with self_text' do
      record = create(:goods_nomenclature_self_text, self_text: 'Widgets for manufacturing')

      described_class.regenerate_search_embeddings([record.goods_nomenclature_sid])

      record.reload
      expect(record.search_text).to be_present
      expect(record.search_embedding).to be_present
    end

    it 'skips SIDs with no self-text records' do
      described_class.regenerate_search_embeddings([-999])

      expect(embedding_service).not_to have_received(:embed_batch)
    end

    it 'does nothing for empty SID list' do
      described_class.regenerate_search_embeddings([])

      expect(embedding_service).not_to have_received(:embed_batch)
    end
  end

  describe '#context_stale?' do
    it 'returns true when hash differs from stored hash' do
      record = build(:goods_nomenclature_self_text, context_hash: 'abc123')
      expect(record.context_stale?('different_hash')).to be true
    end

    it 'returns false when hash matches stored hash' do
      record = build(:goods_nomenclature_self_text, context_hash: 'abc123')
      expect(record.context_stale?('abc123')).to be false
    end
  end
end
