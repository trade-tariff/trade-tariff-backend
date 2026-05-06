RSpec.describe CustomsTariffSectionNote do
  describe 'status default' do
    it 'defaults to pending' do
      note = create(:customs_tariff_section_note)
      expect(note.status).to eq(CustomsTariffSectionNote::PENDING)
    end
  end

  describe 'dataset scopes' do
    let!(:pending_note)  { create(:customs_tariff_section_note) }
    let!(:approved_note) { create(:customs_tariff_section_note, :approved) }
    let!(:rejected_note) { create(:customs_tariff_section_note, :rejected) }

    describe '.pending' do
      it 'returns only pending records' do
        expect(described_class.pending.all).to contain_exactly(pending_note)
      end
    end

    describe '.approved' do
      it 'returns only approved records' do
        expect(described_class.approved.all).to contain_exactly(approved_note)
      end
    end

    describe '.rejected' do
      it 'returns only rejected records' do
        expect(described_class.rejected.all).to contain_exactly(rejected_note)
      end
    end
  end
end
