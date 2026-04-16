RSpec.describe CustomsTariffUpdate do
  describe 'dataset scopes' do
    let!(:awaiting) { create(:customs_tariff_update, status: CustomsTariffUpdate::AWAITING_APPROVAL) }
    let!(:approved) { create(:customs_tariff_update, :approved) }
    let!(:failed)   { create(:customs_tariff_update, :failed) }

    describe '.awaiting_approval' do
      it 'returns only awaiting_approval records' do
        expect(described_class.awaiting_approval.all).to contain_exactly(awaiting)
      end
    end

    describe '.approved' do
      it 'returns only approved records' do
        expect(described_class.approved.all).to contain_exactly(approved)
      end
    end

    describe '.failed' do
      it 'returns only failed records' do
        expect(described_class.failed.all).to contain_exactly(failed)
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
      create(:customs_tariff_section_note, customs_tariff_update: update, section_id: 'I')
      expect(update.customs_tariff_section_notes.count).to eq(1)
    end

    it 'has many customs_tariff_general_rules' do
      create(:customs_tariff_general_rule, customs_tariff_update: update, rule_label: '1')
      expect(update.customs_tariff_general_rules.count).to eq(1)
    end
  end
end
