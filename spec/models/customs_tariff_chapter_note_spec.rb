RSpec.describe CustomsTariffChapterNote do
  describe 'paper trail' do
    let!(:update) { create(:customs_tariff_update) }
    let!(:note)   { create(:customs_tariff_chapter_note, customs_tariff_update: update) }

    it 'creates a Version record when content is updated' do
      expect {
        note.update(content: 'Updated content for versioning test')
      }.to change { Version.where(item_type: 'CustomsTariffChapterNote', item_id: note.id.to_s).count }.by(1)
    end
  end

  describe 'scopes' do
    let!(:pending_note) { create(:customs_tariff_chapter_note) }
    let!(:approved_note) { create(:customs_tariff_chapter_note, :approved) }
    let!(:rejected_note) { create(:customs_tariff_chapter_note, :rejected) }

    it 'filters by status', :aggregate_failures do
      expect(described_class.pending.all).to contain_exactly(pending_note)
      expect(described_class.approved.all).to contain_exactly(approved_note)
      expect(described_class.rejected.all).to contain_exactly(rejected_note)
    end
  end
end
