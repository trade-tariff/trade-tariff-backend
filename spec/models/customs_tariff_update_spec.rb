RSpec.describe CustomsTariffUpdate do
  describe 'dataset scopes' do
    let!(:imported_update) { create(:customs_tariff_update) }
    let!(:failed_update)   { create(:customs_tariff_update, :failed) }

    describe '.failed' do
      it 'returns only records with an import error' do
        expect(described_class.failed.all).to contain_exactly(failed_update)
      end
    end

    describe '.imported' do
      it 'returns only records without an import error' do
        expect(described_class.imported.all).to contain_exactly(imported_update)
      end
    end

    describe '.latest' do
      it 'returns the latest imported update for the current TimeMachine date' do
        older_update  = create(:customs_tariff_update, version: '1.30', validity_start_date: Date.new(2026, 1, 22))
        latest_update = create(:customs_tariff_update, version: '1.31', validity_start_date: Date.new(2026, 4, 1))
        create(:customs_tariff_update, :failed, version: '1.32', validity_start_date: Date.new(2026, 6, 1))
        create(:customs_tariff_update, version: '1.33', validity_start_date: Date.new(2026, 8, 1))

        update = TimeMachine.at(Date.new(2026, 7, 1)) { described_class.latest.first }

        expect(update).to eq(latest_update)
        expect(update).not_to eq(older_update)
      end
    end
  end

  describe 'associations' do
    let(:update) { create(:customs_tariff_update) }

    it 'has many customs_tariff_chapter_notes' do
      create(:customs_tariff_chapter_note, customs_tariff_update: update, chapter_id: '01')
      expect(update.customs_tariff_chapter_notes.count).to eq(1)
    end

    it 'has many customs_tariff_section_notes' do
      create(:customs_tariff_section_note, customs_tariff_update: update, section_id: '1')
      expect(update.customs_tariff_section_notes.count).to eq(1)
    end

    it 'has many customs_tariff_general_rules' do
      create(:customs_tariff_general_rule, customs_tariff_update: update, rule_label: '1')
      expect(update.customs_tariff_general_rules.count).to eq(1)
    end
  end
end
