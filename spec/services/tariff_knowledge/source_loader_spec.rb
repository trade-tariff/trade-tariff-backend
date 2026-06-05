RSpec.describe TariffKnowledge::SourceLoader do
  describe '.call' do
    subject(:sources) { described_class.call }

    let(:actual_update) do
      create(
        :customs_tariff_update,
        :approved,
        version: '1.30',
        validity_start_date: Time.zone.yesterday,
        validity_end_date: nil,
      )
    end
    let(:older_update) do
      create(
        :customs_tariff_update,
        :approved,
        version: '1.29',
        validity_start_date: 1.month.ago,
        validity_end_date: 1.day.ago,
      )
    end

    before do
      create(:chapter_note, chapter_id: 1, content: 'Legacy chapter note.')
      create(:section_note, section_id: 1, content: 'Legacy section note.')
      create(:customs_tariff_chapter_note, :approved, customs_tariff_update: older_update, chapter_id: '01')
      create(:customs_tariff_chapter_note, customs_tariff_update: actual_update, chapter_id: '02')
      create(:customs_tariff_chapter_note, :approved, customs_tariff_update: actual_update, chapter_id: '03')
      create(:customs_tariff_section_note, :approved, customs_tariff_update: actual_update, section_id: 6)
    end

    it 'loads only approved customs tariff notes on the actual update' do
      expect(sources.map(&:key)).to contain_exactly(
        'customs_tariff_chapter_note:1.30:03',
        'customs_tariff_section_note:1.30:6',
      )
    end

    it 'marks customs notes as the source type' do
      expect(sources.map(&:source_type)).to contain_exactly(
        'CustomsTariffChapterNote',
        'CustomsTariffSectionNote',
      )
    end
  end
end
