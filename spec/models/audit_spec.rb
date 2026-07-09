RSpec.describe Audit do
  describe 'auditable association' do
    let(:change) { create(:change) }

    it 'loads the auditable record', :aggregate_failures do
      audit = described_class.create(action: 'update', changes: {}, auditable: change)

      expect(audit.auditable_id).to eq(change.id)
      expect(audit.auditable_type).to eq('Change')
      expect(audit.created_at).to be_present
      expect(described_class[audit.id].auditable).to eq(change)
      expect(described_class.eager(:auditable).all.first.auditable).to eq(change)
    end
  end

  describe '#before_create' do
    let(:change) { create(:change) }

    before do
      described_class.create(action: 'update', changes: {}, auditable: change)
    end

    it 'sets the next version' do
      audit = described_class.create(action: 'update', changes: {}, auditable: change)

      expect(audit.version).to eq(2)
    end
  end
end
