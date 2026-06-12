RSpec.describe ProrogationRegulation do
  let(:regulation) { described_class.load(prorogation_regulation_role: 5) }

  describe '#role' do
    it { expect(regulation.role).to eq regulation.prorogation_regulation_role }
  end
end
