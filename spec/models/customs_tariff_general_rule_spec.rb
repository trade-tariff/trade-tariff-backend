RSpec.describe CustomsTariffGeneralRule do
  describe 'status default' do
    it 'defaults to pending' do
      rule = create(:customs_tariff_general_rule)
      expect(rule.status).to eq(CustomsTariffGeneralRule::PENDING)
    end
  end

  describe 'dataset scopes' do
    let!(:pending_rule)  { create(:customs_tariff_general_rule) }
    let!(:approved_rule) { create(:customs_tariff_general_rule, :approved) }
    let!(:rejected_rule) { create(:customs_tariff_general_rule, :rejected) }

    describe '.pending' do
      it 'returns only pending records' do
        expect(described_class.pending.all).to contain_exactly(pending_rule)
      end
    end

    describe '.approved' do
      it 'returns only approved records' do
        expect(described_class.approved.all).to contain_exactly(approved_rule)
      end
    end

    describe '.rejected' do
      it 'returns only rejected records' do
        expect(described_class.rejected.all).to contain_exactly(rejected_rule)
      end
    end
  end
end
