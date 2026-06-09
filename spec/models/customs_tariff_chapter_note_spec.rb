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
end
