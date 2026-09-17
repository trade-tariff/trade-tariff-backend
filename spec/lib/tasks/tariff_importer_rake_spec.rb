RSpec.describe 'tariff importer rake tasks' do
  describe 'importer:cds:import' do
    subject(:task) { Rake::Task['importer:cds:import'] }

    let(:target) { 'data/cds/tariff_dailyExtract_v1_20210101T235959.gzip' }
    let(:importer) { instance_double(CdsImporter, import: true) }

    around do |example|
      original_target = ENV['TARGET']
      example.run
      ENV['TARGET'] = original_target
    end

    before do
      Rake::Task['class_eager_load'].reenable
      allow(Rails.application).to receive(:eager_load!).and_return(true)
      allow(Sequel::Model).to receive(:subclasses).and_return([])
      allow(Sequel::Model).to receive(:plugin)
      allow(CdsImporter).to receive(:new).and_return(importer)
    end

    after { task.reenable }

    it 'builds and runs the importer when TARGET exists', :aggregate_failures do
      ENV['TARGET'] = target
      allow(TariffSynchronizer::FileService).to receive(:file_exists?).with(target).and_return(true)

      task.invoke

      expect(CdsImporter).to have_received(:new) do |dummy_update|
        expect(dummy_update.file_path).to eq(target)
        expect(dummy_update.issue_date).to be_nil
      end
      expect(importer).to have_received(:import)
    end

    it 'prints guidance when TARGET is missing' do
      ENV['TARGET'] = nil

      expect { task.invoke }
        .to output("Please provide TARGET environment variable pointing to Tariff file to import\n").to_stdout
    end
  end
end
