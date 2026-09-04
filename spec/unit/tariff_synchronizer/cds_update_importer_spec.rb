RSpec.describe TariffSynchronizer::CdsUpdateImporter do
  def inserted_oplog_records(total_count)
    {
      total_count: total_count,
      total_duration: 0,
      total_allocations: 0,
    }
  end

  describe '#import!' do
    let(:cds_update) { create :cds_update }

    before do
      allow(cds_update).to receive_messages(file_path: 'spec/fixtures/cds_samples/tariff_dailyExtract_v1_20201010T235959.gzip', filesize: 57_000)

      cds_importer = instance_double(CdsImporter)
      allow(CdsImporter).to receive(:new).with(cds_update, staging_manager: instance_of(TariffSynchronizer::StagingManager)).and_return(cds_importer)
      allow(cds_importer).to receive(:import).and_return inserted_oplog_records(3)
    end

    it 'calls the CdsImporter import method', :aggregate_failures do
      cds_importer = instance_double(CdsImporter)
      allow(CdsImporter).to receive(:new).with(cds_update, staging_manager: instance_of(TariffSynchronizer::StagingManager)).and_return(cds_importer)
      allow(cds_importer).to receive(:import).and_return inserted_oplog_records(3)
      allow(TariffSynchronizer::Instrumentation).to receive(:file_import_completed)
      described_class.new(cds_update).import!

      expect(TariffSynchronizer::Instrumentation).to have_received(:file_import_completed)
      expect(CdsImporter).to have_received(:new).with(cds_update, staging_manager: instance_of(TariffSynchronizer::StagingManager))
      expect(cds_importer).to have_received(:import)
    end

    it 'marks the Cds update as applied' do
      described_class.new(cds_update).import!
      expect(cds_update.reload).to be_applied
    end

    describe 'checking results of import' do
      let(:cds_importer) { instance_double(CdsImporter) }

      before do
        allow(CdsImporter).to receive(:new).with(cds_update, staging_manager: instance_of(TariffSynchronizer::StagingManager)).and_return cds_importer
        allow(cds_importer).to receive(:import).and_return inserted_oplog_records(1)
        allow(NewRelic::Agent).to receive(:notice_error)

        described_class.new(cds_update).import!
      end

      context 'with valid upload' do
        before do
          allow(CdsImporter).to receive(:new).with(cds_update, staging_manager: instance_of(TariffSynchronizer::StagingManager)).and_return cds_importer
          allow(cds_importer).to receive(:import).and_return inserted_oplog_records(1)
          allow(NewRelic::Agent).to receive(:notice_error)
        end

        it 'stores the inserts on the update' do
          expect(cds_update.reload.inserts).to include('"total_count":1')
        end

        it 'does not alert' do
          expect(NewRelic::Agent).not_to have_received(:notice_error)
        end
      end
    end

    describe 'with empty results of import' do
      let(:cds_importer) { instance_double(CdsImporter) }

      before do
        allow(CdsImporter).to receive(:new).with(cds_update, staging_manager: instance_of(TariffSynchronizer::StagingManager)).and_return cds_importer
        allow(cds_importer).to receive(:import).and_return inserted_oplog_records(0)
        allow(NewRelic::Agent).to receive(:notice_error)
      end

      context 'with empty but valid upload' do
        before do
          allow(cds_update).to receive(:filesize).and_return(477)

          described_class.new(cds_update).import!
        end

        it 'does not alert' do
          expect(NewRelic::Agent).not_to have_received(:notice_error)
        end
      end

      context 'with missing inserts' do
        before do
          described_class.new(cds_update).import!
        end

        it 'alerts' do
          expect(NewRelic::Agent).to have_received(:notice_error)
                                       .with(/Empty CDS update - Issue Date: \d{4}-\d\d-\d\d: Applied: #{Time.zone.today}/)
        end
      end
    end
  end
end
