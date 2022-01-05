RSpec.describe TariffSynchronizer::CdsUpdate do
  let(:example_date) { Date.new(2020, 10, 10) }

  let(:inserted_oplog_records) do
    {
      'AdditionalCode::Operation' => 2,
      'Measure::Operation' => 1,
    }
  end

  it_behaves_like 'Base Update'

  describe '.download' do
    it 'calls CdsUpdateDownloader perform for a Cds update' do
      downloader = instance_double('TariffSynchronizer::CdsUpdateDownloader', perform: true)
      expect(TariffSynchronizer::CdsUpdateDownloader).to receive(:new)
        .with(example_date)
        .and_return(downloader)
      described_class.download(example_date)
    end
  end

  describe '#import!' do
    let(:cds_update) { create :cds_update }
    let(:filesize) { 57_000 }

    before do
      # stub the file_path method to return a valid path of a real file.
      allow(cds_update).to receive(:file_path).and_return('spec/fixtures/cds_samples/tariff_dailyExtract_v1_20201010T235959.gzip')
      allow(cds_update).to receive(:filesize).and_return filesize
    end

    it 'calls the CdsImporter import method' do
      cds_importer = instance_double('CdsImporter')
      expect(CdsImporter).to receive(:new).with(cds_update).and_return(cds_importer)
      expect(cds_importer).to receive(:import).and_return inserted_oplog_records
      cds_update.import!
    end

    it 'marks the Cds update as applied' do
      allow_any_instance_of(CdsImporter).to \
        receive(:import).and_return inserted_oplog_records
      cds_update.import!
      expect(cds_update.reload).to be_applied
    end

    it 'logs an info event' do
      tariff_synchronizer_logger_listener
      allow_any_instance_of(CdsImporter).to \
        receive(:import).and_return inserted_oplog_records
      cds_update.import!
      expect(@logger.logged(:info).size).to eq 1
      expect(@logger.logged(:info).last).to match(/Applied CDS update/)
    end

    describe 'checking results of import' do
      before do
        allow(CdsImporter).to receive(:new).with(cds_update).and_return importer
        allow(importer).to receive(:import).and_return inserted_oplog_records
        allow(Sentry).to receive(:capture_message)
        allow(cds_update).to receive(:check_oplog_inserts).and_call_original

        cds_update.import!
      end

      let(:importer) { CdsImporter.new(cds_update) }

      context 'with valid upload' do
        it 'will check the import' do
          expect(cds_update).to have_received(:check_oplog_inserts)
        end

        it 'will not alert' do
          expect(Sentry).not_to have_received(:capture_message)
        end
      end

      context 'with empty but valid upload' do
        let(:filesize) { 477 }

        let(:inserted_oplog_records) do
          {
            'AdditionalCode::Operation' => 0,
            'Measure::Operation' => 0,
          }
        end

        it 'will check the import' do
          expect(cds_update).to have_received(:check_oplog_inserts)
        end

        it 'will not alert' do
          expect(Sentry).not_to have_received(:capture_message)
        end
      end

      context 'with missing inserts' do
        let(:inserted_oplog_records) do
          {
            'AdditionalCode::Operation' => 0,
            'Measure::Operation' => 0,
          }
        end

        it 'will check the import' do
          expect(cds_update).to have_received(:check_oplog_inserts)
        end

        it 'will alert' do
          expect(Sentry).to have_received(:capture_message)
                             .with(/Empty CDS update - Issue Date: \d{4}-\d\d-\d\d: Applied: #{Time.zone.today}/)
        end
      end
    end
  end
end
