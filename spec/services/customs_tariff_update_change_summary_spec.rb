RSpec.describe CustomsTariffUpdateChangeSummary do
  describe '#call' do
    it 'treats a chapter/section with no previous version as changed' do
      update = create(:customs_tariff_update, validity_start_date: Date.new(2026, 2, 1))
      create(:customs_tariff_chapter_note, customs_tariff_update: update, chapter_id: '01', content: 'New chapter note')
      create(:customs_tariff_section_note, customs_tariff_update: update, section_id: 1, content: 'New section note')

      result = described_class.new(update).call

      expect(result[:chapter_ids]).to eq(%w[01])
      expect(result[:section_ids]).to eq([1])
    end

    it 'excludes a chapter whose content is unchanged from the previous version' do
      previous_update = create(:customs_tariff_update, validity_start_date: Date.new(2026, 1, 1))
      create(:customs_tariff_chapter_note, customs_tariff_update: previous_update, chapter_id: '01', content: 'Unchanged content')

      update = create(:customs_tariff_update, validity_start_date: Date.new(2026, 2, 1))
      create(:customs_tariff_chapter_note, customs_tariff_update: update, chapter_id: '01', content: 'Unchanged content')

      result = described_class.new(update).call

      expect(result[:chapter_ids]).to eq([])
    end

    it 'includes a chapter whose content differs from the previous version' do
      previous_update = create(:customs_tariff_update, validity_start_date: Date.new(2026, 1, 1))
      create(:customs_tariff_chapter_note, customs_tariff_update: previous_update, chapter_id: '01', content: 'Old content')

      update = create(:customs_tariff_update, validity_start_date: Date.new(2026, 2, 1))
      create(:customs_tariff_chapter_note, customs_tariff_update: update, chapter_id: '01', content: 'New content')

      result = described_class.new(update).call

      expect(result[:chapter_ids]).to eq(%w[01])
    end

    it 'ignores a failed update when looking for the previous baseline' do
      create(:customs_tariff_update, :failed, validity_start_date: Date.new(2026, 1, 15))
      previous_update = create(:customs_tariff_update, validity_start_date: Date.new(2026, 1, 1))
      create(:customs_tariff_chapter_note, customs_tariff_update: previous_update, chapter_id: '01', content: 'Old content')

      update = create(:customs_tariff_update, validity_start_date: Date.new(2026, 2, 1))
      create(:customs_tariff_chapter_note, customs_tariff_update: update, chapter_id: '01', content: 'Old content')

      result = described_class.new(update).call

      expect(result[:chapter_ids]).to eq([])
    end

    it 'returns sorted chapter and section ids' do
      update = create(:customs_tariff_update, validity_start_date: Date.new(2026, 2, 1))
      create(:customs_tariff_chapter_note, customs_tariff_update: update, chapter_id: '99', content: 'note')
      create(:customs_tariff_chapter_note, customs_tariff_update: update, chapter_id: '01', content: 'note')
      create(:customs_tariff_section_note, customs_tariff_update: update, section_id: 21, content: 'note')
      create(:customs_tariff_section_note, customs_tariff_update: update, section_id: 1, content: 'note')

      result = described_class.new(update).call

      expect(result[:chapter_ids]).to eq(%w[01 99])
      expect(result[:section_ids]).to eq([1, 21])
    end
  end
end
