RSpec.describe 'search_references rake tasks' do
  describe 'search_references:import_fpo' do
    subject(:import_fpo) { Rake::Task['search_references:import_fpo'].invoke }

    after { Rake::Task['search_references:import_fpo'].reenable }

    before { allow(SearchReferences::FpoCsvImporter).to receive(:call) }

    it 'imports the default CSV' do
      import_fpo

      expect(SearchReferences::FpoCsvImporter).to have_received(:call)
        .with(Rails.root.join('data/fpo_extra_references.csv').to_s, dry_run: false, whodunnit: 'fpo_csv_import')
    end

    it 'imports the CSV given in CSV with DRY_RUN' do
      stub_const('ENV', ENV.to_h.merge('CSV' => '/tmp/refs.csv', 'DRY_RUN' => 'true'))

      import_fpo

      expect(SearchReferences::FpoCsvImporter).to have_received(:call).with('/tmp/refs.csv', dry_run: true, whodunnit: 'fpo_csv_import')
    end

    it 'passes WHODUNNIT to the importer' do
      stub_const('ENV', ENV.to_h.merge('WHODUNNIT' => 'jane@example.com'))

      import_fpo

      expect(SearchReferences::FpoCsvImporter).to have_received(:call)
        .with(anything, dry_run: false, whodunnit: 'jane@example.com')
    end

    it 'aborts in the XI service' do
      allow(TradeTariffBackend).to receive(:uk?).and_return(false)

      expect { import_fpo }.to raise_error(SystemExit).and output(/only in the UK service/).to_stderr
    end

    it 'has a default CSV that exists' do
      expect(Rails.root.join('data/fpo_extra_references.csv')).to exist
    end
  end
end
