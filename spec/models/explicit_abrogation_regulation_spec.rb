RSpec.describe ExplicitAbrogationRegulation do
  let(:ear) { build :explicit_abrogation_regulation }

  describe '#role' do
    it { expect(ear.role).to eq ear.explicit_abrogation_regulation_role }
  end
end
