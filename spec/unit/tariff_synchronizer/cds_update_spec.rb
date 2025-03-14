RSpec.describe TariffSynchronizer::CdsUpdate do
  let(:example_date) { Date.new(2020, 10, 10) }

  let(:inserted_oplog_records) do
    {
      total_count: 3,
      total_duration: 0,
      total_allocations: 0,
    }
  end

  it_behaves_like 'Base Update'

  describe '.download' do
    it 'calls CdsUpdateDownloader perform for a Cds update' do
      downloader = instance_spy(TariffSynchronizer::CdsUpdateDownloader, perform: true)
      allow(TariffSynchronizer::CdsUpdateDownloader).to receive(:new)
                                                          .with(example_date)
                                                          .and_return(downloader)
      described_class.download(example_date)
      expect(TariffSynchronizer::CdsUpdateDownloader).to have_received(:new)
                                                           .with(example_date)
    end
  end

  describe '.downloaded_todays_file?' do
    subject { described_class.downloaded_todays_file? }

    context 'when todays file is present in table' do
      # Note published day after file name, so todays file has yesterdays date
      before { create :cds_update, example_date: Time.zone.yesterday }

      it { is_expected.to be true }
    end

    context 'when todays file is not present in table' do
      it { is_expected.to be false }
    end

    context 'when yesterdays file queued in table' do
      # Note published day after file name, so yesterdays file is 2 days old
      before { create :cds_update, example_date: 2.days.ago.to_date }

      it { is_expected.to be false }
    end
  end

  describe '#import!' do
    let(:cds_update) { create :cds_update }
    let(:filesize) { 57_000 }

    before do
      # stub the file_path method to return a valid path of a real file.
      allow(cds_update).to receive_messages(file_path: 'spec/fixtures/cds_samples/tariff_dailyExtract_v1_20201010T235959.gzip', filesize:)

      cds_importer = instance_double(CdsImporter)
      allow(CdsImporter).to receive(:new).with(cds_update).and_return(cds_importer)
      allow(cds_importer).to receive(:import).and_return inserted_oplog_records
    end

    it 'calls the CdsImporter import method', :aggregate_failures do
      cds_importer = instance_double(CdsImporter)
      allow(CdsImporter).to receive(:new).with(cds_update).and_return(cds_importer)
      allow(cds_importer).to receive(:import).and_return inserted_oplog_records
      allow(Rails.logger).to receive(:info)
      cds_update.import!

      expect(Rails.logger).to have_received(:info)
      expect(CdsImporter).to have_received(:new).with(cds_update)
      expect(cds_importer).to have_received(:import)
    end

    it 'marks the Cds update as applied' do
      cds_update.import!
      expect(cds_update.reload).to be_applied
    end

    describe 'checking results of import' do
      before do
        allow(CdsImporter).to receive(:new).with(cds_update).and_return importer
        allow(importer).to receive(:import).and_return inserted_oplog_records
        allow(NewRelic::Agent).to receive(:notice_error)
        allow(cds_update).to receive(:check_oplog_inserts).and_call_original

        cds_update.import!
      end

      let(:importer) { CdsImporter.new(cds_update) }

      let(:inserted_oplog_records) do
        {
          total_count: 1,
          total_duration: 0,
          total_allocations: 0,
        }
      end

      context 'with valid upload' do
        it 'stores the inserts on the update' do
          expect(cds_update.reload.inserts).to include('"total_count":1')
        end

        it 'checks the import' do
          expect(cds_update).to have_received(:check_oplog_inserts)
        end

        it 'does not alert' do
          expect(NewRelic::Agent).not_to have_received(:notice_error)
        end
      end

      context 'with empty but valid upload' do
        let(:filesize) { 477 }

        let(:inserted_oplog_records) do
          {
            total_count: 0,
            total_duration: 0,
            total_allocations: 0,
          }
        end

        it 'checks the import' do
          expect(cds_update).to have_received(:check_oplog_inserts)
        end

        it 'does not alert' do
          expect(NewRelic::Agent).not_to have_received(:notice_error)
        end
      end

      context 'with missing inserts' do
        let(:inserted_oplog_records) do
          {
            total_count: 0,
            total_duration: 0,
            total_allocations: 0,
          }
        end

        it 'checks the import' do
          expect(cds_update).to have_received(:check_oplog_inserts)
        end

        it 'alerts' do
          expect(NewRelic::Agent).to have_received(:notice_error)
                             .with(/Empty CDS update - Issue Date: \d{4}-\d\d-\d\d: Applied: #{Time.zone.today}/)
        end
      end
    end
  end

  describe '.correct_filename_sequence?' do
    subject(:cds_update) { described_class }

    before do
      create(:cds_update, :applied, example_date: applied_date)
      create(:cds_update, :pending, example_date: pending_date)
    end

    let(:applied_date) { Time.zone.yesterday }

    context 'when the sequence date is correct' do
      let(:pending_date) { applied_date + 1.day }

      it { is_expected.to be_correct_filename_sequence }
    end

    context 'when the sequence date is incorrect' do
      let(:pending_date) { applied_date + 2.days }

      it { is_expected.not_to be_correct_filename_sequence }
    end
  end

  describe '#filename_sequence' do
    subject(:cds_update) { create(:cds_update, filename:) }

    let(:filename) { 'tariff_dailyExtract_v1_20220118T235959.gzip' }

    it 'returns the sequence date' do
      expect(cds_update.filename_sequence).to eq Date.new(2022, 0o1, 18)
    end
  end
end
