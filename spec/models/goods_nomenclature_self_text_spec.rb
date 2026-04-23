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

  describe '.admin_listing' do
    let(:commodity) { create(:goods_nomenclature, producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX) }

    it 'excludes expired self-texts by default' do
      create(:goods_nomenclature_self_text, :ai_generated, goods_nomenclature: commodity, expired: true)

      expect(described_class.admin_listing.all).to be_empty
    end
  end

  describe '.for_status' do
    let(:commodity_a) { create(:goods_nomenclature, producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX) }
    let(:commodity_b) { create(:goods_nomenclature, producline_suffix: GoodsNomenclature::NON_GROUPING_PRODUCTLINE_SUFFIX) }

    before do
      create(:goods_nomenclature_self_text, :ai_generated, goods_nomenclature: commodity_a, needs_review: true)
      create(:goods_nomenclature_self_text, :ai_generated, goods_nomenclature: commodity_b, approved: true)
    end

    it 'filters to records needing review' do
      results = described_class.admin_listing.for_status('needs_review').all

      expect(results.length).to eq(1)
      expect(results.first.needs_review).to be true
    end

    it 'filters to approved records' do
      results = described_class.admin_listing.for_status('approved').all

      expect(results.length).to eq(1)
      expect(results.first.approved).to be true
    end
  end

  describe '#mark_stale!' do
    it 'sets stale to true' do
      record = create(:goods_nomenclature_self_text, stale: false)
      record.mark_stale!

      expect(record.reload.stale).to be true
    end
  end

  describe 'lifecycle transitions' do
    describe '#mark_needs_review!' do
      it 'marks the record for review and clears approval' do
        record = create(:goods_nomenclature_self_text, needs_review: false, approved: true)

        record.mark_needs_review!

        expect(record.reload).to have_attributes(
          needs_review: true,
          approved: false,
        )
      end
    end

    describe '#approve!' do
      it 'approves the current content and clears review' do
        record = create(:goods_nomenclature_self_text, needs_review: true, approved: false)

        record.approve!

        expect(record.reload).to have_attributes(
          needs_review: false,
          approved: true,
        )
      end
    end

    describe '#apply_manual_edit!' do
      it 'updates the text, records the manual edit, approves it and clears review' do
        record = create(:goods_nomenclature_self_text, needs_review: true, approved: false, manually_edited: false)

        record.apply_manual_edit!(self_text: 'Operator corrected description')

        expect(record.reload).to have_attributes(
          self_text: 'Operator corrected description',
          needs_review: false,
          approved: true,
          manually_edited: true,
        )
      end
    end

    describe '#apply_pipeline_generation!' do
      it 'updates generated content and clears stale review state for non-manually-edited records' do
        record = create(:goods_nomenclature_self_text, :stale, needs_review: true, approved: true, manually_edited: false)
        input_context = { 'description' => 'Updated widgets' }

        result = record.apply_pipeline_generation!(
          self_text: 'Generated replacement',
          generation_type: 'ai',
          input_context: input_context,
          context_hash: 'fresh-hash',
          generated_at: Time.zone.now,
        )

        expect(result).to be true
        expect(record.reload).to have_attributes(
          self_text: 'Generated replacement',
          generation_type: 'ai',
          context_hash: 'fresh-hash',
          stale: false,
          needs_review: false,
          approved: false,
          manually_edited: false,
        )
      end

      it 'does not update manually edited records' do
        record = create(:goods_nomenclature_self_text,
                        :stale,
                        self_text: 'Operator text',
                        manually_edited: true,
                        approved: true)

        result = record.apply_pipeline_generation!(
          self_text: 'Generated replacement',
          generation_type: 'ai',
          input_context: { 'description' => 'Updated widgets' },
          context_hash: 'fresh-hash',
          generated_at: Time.zone.now,
        )

        expect(result).to be false
        expect(record.reload).to have_attributes(
          self_text: 'Operator text',
          stale: true,
          manually_edited: true,
          approved: true,
        )
      end
    end

    describe '#apply_ui_regeneration!' do
      it 'can replace manually edited content and clears lifecycle review tags' do
        record = create(:goods_nomenclature_self_text,
                        :stale,
                        self_text: 'Operator text',
                        needs_review: true,
                        approved: true,
                        manually_edited: true)

        record.apply_ui_regeneration!(
          self_text: 'Generated replacement',
          generation_type: 'ai_non_other',
          input_context: { 'description' => 'Updated widgets' },
          context_hash: 'fresh-hash',
          generated_at: Time.zone.now,
        )

        expect(record.reload).to have_attributes(
          self_text: 'Generated replacement',
          generation_type: 'ai_non_other',
          context_hash: 'fresh-hash',
          stale: false,
          needs_review: false,
          approved: false,
          manually_edited: false,
        )
      end
    end

    describe '#mark_expired!' do
      it 'marks the record expired' do
        record = create(:goods_nomenclature_self_text, expired: false)

        record.mark_expired!

        expect(record.reload.expired).to be true
      end
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

    it 'skips embedding when composite text matches stored search_text' do
      record = create(:goods_nomenclature_self_text, self_text: 'Widgets for manufacturing')

      # First call to populate search_text and embedding
      described_class.regenerate_search_embeddings([record.goods_nomenclature_sid])
      expect(embedding_service).to have_received(:embed_batch).once

      # Second call should skip because text hasn't changed
      described_class.regenerate_search_embeddings([record.goods_nomenclature_sid])
      expect(embedding_service).to have_received(:embed_batch).once
    end

    it 're-embeds when composite text differs from stored search_text' do
      record = create(:goods_nomenclature_self_text, self_text: 'Widgets for manufacturing')

      described_class.regenerate_search_embeddings([record.goods_nomenclature_sid])
      expect(embedding_service).to have_received(:embed_batch).once

      # Simulate text change by updating search_text to something different
      record.update(search_text: 'outdated text')

      described_class.regenerate_search_embeddings([record.goods_nomenclature_sid])
      expect(embedding_service).to have_received(:embed_batch).twice
    end

    it 're-embeds when search_embedding is nil even if search_text matches' do
      record = create(:goods_nomenclature_self_text, self_text: 'Widgets for manufacturing')

      # First call populates search_text and search_embedding
      described_class.regenerate_search_embeddings([record.goods_nomenclature_sid])
      expect(embedding_service).to have_received(:embed_batch).once

      # Clear embedding via SQL (keeping search_text intact)
      Sequel::Model.db.run(
        "UPDATE goods_nomenclature_self_texts SET search_embedding = NULL WHERE goods_nomenclature_sid = #{record.goods_nomenclature_sid}",
      )

      described_class.regenerate_search_embeddings([record.goods_nomenclature_sid])
      expect(embedding_service).to have_received(:embed_batch).twice
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
