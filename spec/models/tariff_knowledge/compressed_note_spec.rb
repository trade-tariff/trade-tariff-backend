RSpec.describe TariffKnowledge::CompressedNote do
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
  end
end
