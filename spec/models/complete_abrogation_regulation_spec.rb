RSpec.describe CompleteAbrogationRegulation do
  let(:regulation) { build :complete_abrogation_regulation }

  describe '#role' do
    it { expect(regulation.role).to eq regulation.complete_abrogation_regulation_role }
  end
end
