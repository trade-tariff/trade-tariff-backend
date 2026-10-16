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

  describe 'the search reference changes report' do
    subject(:report) { described_class.fetch!('search_reference_changes') }

    %w[uk xi].each do |service|
      it "is available on the #{service.upcase} service" do
        allow(TradeTariffBackend).to receive(:service).and_return(service)

        expect(report.report_class).to eq(Reporting::SearchReferenceChanges)
      end
    end

    it 'supports email and standalone generation' do
      expect(report).to have_attributes(supports_email?: true, supports_generate?: true)
    end

    it 'enqueues the report worker with email delivery' do
      allow(SearchReferenceChangesReportWorker).to receive(:perform_async)

      report.send_email!

      expect(SearchReferenceChangesReportWorker).to have_received(:perform_async).with(no_args)
    end
  end

  describe '#supports_generate?' do
    it 'is false for a report that only supports generate and email' do
      allow(TradeTariffBackend).to receive(:service).and_return('uk')

      expect(described_class.fetch!('differences')).not_to be_supports_generate
    end

    it 'is true for a report without email' do
      expect(described_class.fetch!('commodities')).to be_supports_generate
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
