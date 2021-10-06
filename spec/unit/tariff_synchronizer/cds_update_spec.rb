RSpec.describe TariffSynchronizer::CdsUpdate do
  let(:example_date) { Date.new(2020, 10, 10) }

  it_behaves_like 'Base Update'

  describe '.download' do
    it 'calls CdsUpdateDownloader perform for a Cds update' do
      downlader = instance_double('TariffSynchronizer::CdsUpdateDownloader', perform: true)
      expect(TariffSynchronizer::CdsUpdateDownloader).to receive(:new)
        .with(example_date)
        .and_return(downlader)
      described_class.download(example_date)
    end
  end

  describe '#import!' do
    let(:cds_update) { create :cds_update }

    before do
      # stub the file_path method to return a valid path of a real file.
      allow(cds_update).to receive(:file_path).and_return('spec/fixtures/cds_samples/tariff_dailyExtract_v1_20201010T235959.gzip')
    end

    it 'calls the CdsImporter import method' do
      cds_importer = instance_double('CdsImporter')
      expect(CdsImporter).to receive(:new).with(cds_update).and_return(cds_importer)
      expect(cds_importer).to receive(:import)
      cds_update.import!
    end

    it 'marks the Cds update as applied' do
      allow_any_instance_of(CdsImporter).to receive(:import)
      cds_update.import!
      expect(cds_update.reload).to be_applied
    end

    it 'logs an info event' do
      tariff_synchronizer_logger_listener
      allow_any_instance_of(CdsImporter).to receive(:import)
      cds_update.import!
      expect(@logger.logged(:info).size).to eq 1
      expect(@logger.logged(:info).last).to match(/Applied CDS update/)
    end
  end
end
