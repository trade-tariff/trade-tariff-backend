RSpec.describe Reporting::AdminReportRegistry do
  describe 'the differences report dependencies' do
    subject(:differences) { described_class.fetch!('differences') }

    let(:uk_commodities_key) { Reporting::Commodities.uk_object_key }
    let(:xi_commodities_key) { Reporting::Commodities.xi_object_key }
    let(:uk_supplementary_units_key) { Reporting::SupplementaryUnits.uk_object_key }
    let(:xi_supplementary_units_key) { Reporting::SupplementaryUnits.xi_object_key }

    before do
      allow(TradeTariffBackend).to receive(:service).and_return('uk')
      allow(Reporting).to receive(:published_exist?).and_return(true)
    end

    it 'checks one distinct object key per dependency' do
      differences.missing_dependency_ids

      expect(Reporting).to have_received(:published_exist?).with(uk_commodities_key)
      expect(Reporting).to have_received(:published_exist?).with(xi_commodities_key)
      expect(Reporting).to have_received(:published_exist?).with(uk_supplementary_units_key)
      expect(Reporting).to have_received(:published_exist?).with(xi_supplementary_units_key)
    end

    it 'reports nothing missing when every dependency is published' do
      expect(differences.missing_dependencies).to be_empty
    end

    context 'when only the XI commodities report is missing' do
      before do
        allow(Reporting).to receive(:published_exist?).with(xi_commodities_key).and_return(false)
      end

      it 'flags the XI commodities dependency' do
        expect(differences.missing_dependencies).to eq(['XI commodities report'])
      end

      it 'considers the dependencies missing' do
        expect(differences).to be_dependencies_missing
      end
    end

    context 'when only the XI supplementary units report is missing' do
      before do
        allow(Reporting).to receive(:published_exist?).with(xi_supplementary_units_key).and_return(false)
      end

      it 'flags the XI supplementary units dependency' do
        expect(differences.missing_dependencies).to eq(['XI supplementary units report'])
      end
    end

    context 'when only the UK commodities report is missing' do
      before do
        allow(Reporting).to receive(:published_exist?).with(uk_commodities_key).and_return(false)
      end

      it 'flags the UK commodities dependency' do
        expect(differences.missing_dependencies).to eq(['UK commodities report'])
      end
    end
  end

  describe 'service scoped object keys' do
    it 'builds the UK commodities key independently of the running service' do
      allow(TradeTariffBackend).to receive(:service).and_return('xi')

      expect(Reporting::Commodities.uk_object_key).to include('commodities_uk_')
    end

    it 'builds the XI supplementary units key independently of the running service' do
      allow(TradeTariffBackend).to receive(:service).and_return('uk')

      expect(Reporting::SupplementaryUnits.xi_object_key).to include('supplementary_units_xi_')
    end
  end
end
