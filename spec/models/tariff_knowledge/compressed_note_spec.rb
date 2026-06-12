RSpec.describe TariffKnowledge::CompressedNote do
  describe 'validations' do
    it 'rejects blank strings for required generated content fields' do
      note = described_class.new(
        goods_nomenclature_item_id: '',
        producline_suffix: '',
        goods_nomenclature_type: '',
        content: '',
        context_hash: '',
      )

      expect(note).not_to be_valid
      expect(note.errors).to include(
        :goods_nomenclature_item_id,
        :producline_suffix,
        :goods_nomenclature_type,
        :content,
        :context_hash,
      )
    end
  end

  describe 'lifecycle' do
    it 'uses the generated content lifecycle for reviewable compressed notes' do
      note = create(:tariff_knowledge_compressed_note, needs_review: true, approved: false)

      note.approve!

      expect(note.reload).to have_attributes(needs_review: false, approved: true)
    end

    it 'tracks manual edits and versions' do
      note = create(:tariff_knowledge_compressed_note, needs_review: true, approved: false)

      expect {
        note.apply_manual_edit!(content: 'Reviewed compressed note')
      }.to change(Version.where(item_type: described_class.name), :count).by(1)

      expect(note.reload).to have_attributes(
        content: 'Reviewed compressed note',
        manually_edited: true,
        needs_review: false,
        approved: true,
      )
    end
  end

  describe 'datasets' do
    it 'looks up notes by goods nomenclature identifiers' do
      note = create(:tariff_knowledge_compressed_note, goods_nomenclature_sid: 123, goods_nomenclature_item_id: '0101210000')

      expect(described_class.by_sids([123]).all).to contain_exactly(note)
      expect(described_class.by_item_ids(%w[0101210000]).all).to contain_exactly(note)
    end

    it 'returns current generated notes that are usable by search' do
      generated_note = create(:tariff_knowledge_compressed_note, approved: false, needs_review: false)
      approved_note = create(:tariff_knowledge_compressed_note, approved: true, needs_review: false)
      create(:tariff_knowledge_compressed_note, approved: false, needs_review: true)
      create(:tariff_knowledge_compressed_note, stale: true, needs_review: false)
      create(:tariff_knowledge_compressed_note, expired: true, needs_review: false)

      expect(described_class.usable_for_search.all).to contain_exactly(generated_note, approved_note)
    end
  end

  describe 'coverage' do
    it 'covers regeneration and context helpers' do
      note = create(:tariff_knowledge_compressed_note, stale: true, manually_edited: false, context_hash: 'old')

      expect([described_class.needing_regeneration.all, note.context_stale?('new')]).to eq([[note], true])
    end
  end
end
