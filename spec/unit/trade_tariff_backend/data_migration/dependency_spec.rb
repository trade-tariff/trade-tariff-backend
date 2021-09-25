RSpec.describe TradeTariffBackend::DataMigration::Dependency do
  describe '#applicable?' do
    context 'one dependency did not meet' do
      let(:dep1) { double('Dependency 1', applicable: false) }
      let(:dep2) { double('Dependency 2', applicable: true) }

      it 'returns false' do
        expect(described_class[dep1, dep2]).not_to be_applicable
      end
    end

    context 'all dependencies met' do
      let(:dep1) { double('Dependency 1', applicable: true) }
      let(:dep2) { double('Dependency 2', applicable: true) }

      it 'returns true' do
        expect(described_class[dep1, dep2]).to be_applicable
      end
    end
  end
end
