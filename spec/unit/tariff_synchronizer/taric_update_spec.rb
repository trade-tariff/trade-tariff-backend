RSpec.describe TariffSynchronizer::TaricUpdate do
  let(:example_date) { Date.new(2010, 1, 1) }

  it_behaves_like 'Base Update'

  describe '.download' do
    it 'calls TaricUpdateDownloader perform for a TARIC update' do
      downlader = instance_double('TariffSynchronizer::TaricUpdateDownloader', perform: true)
      expect(TariffSynchronizer::TaricUpdateDownloader).to receive(:new)
        .with(example_date)
        .and_return(downlader)
      TariffSynchronizer::TaricUpdate.download(example_date)
    end
  end

  describe '#import!' do
    let(:taric_update) { create :taric_update }

    before do
      # stub the file_path method to return a valid path of a real file.
      allow(taric_update).to receive(:file_path).and_return('spec/fixtures/taric_samples/insert_record.xml')
    end

    it 'calls the TaricImporter import method' do
      taric_importer = instance_double('TaricImporter')
      expect(TaricImporter).to receive(:new).with(taric_update).and_return(taric_importer)
      expect(taric_importer).to receive(:import)
      taric_update.import!
    end

    it 'marks the Taric update as applied' do
      allow_any_instance_of(TaricImporter).to receive(:import)
      taric_update.import!
      expect(taric_update.reload).to be_applied
    end

    it 'logs an info event' do
      tariff_synchronizer_logger_listener
      allow_any_instance_of(TaricImporter).to receive(:import)
      taric_update.import!
      expect(@logger.logged(:info).size).to eq 1
      expect(@logger.logged(:info).last).to match(/Applied TARIC update/)
    end
  end
end
