RSpec.describe TariffSynchronizer::CdsUpdateImporter do
  let(:example_date) { Date.new(2020, 10, 10) }

  let(:inserted_oplog_records) do
    {
      total_count: 3,
      total_duration: 0,
      total_allocations: 0,
    }
  end

  describe '#import!' do
    let(:cds_update) { create :cds_update }
    let(:filesize) { 57_000 }
    let(:importer) { described_class.new(cds_update) }

    before do
      allow(cds_update).to receive_messages(file_path: 'spec/fixtures/cds_samples/tariff_dailyExtract_v1_20201010T235959.gzip', filesize:)

      cds_importer = instance_double(CdsImporter)
      allow(CdsImporter).to receive(:new).with(cds_update, staging_manager: instance_of(CdsImporter::StagingManager)).and_return(cds_importer)
      allow(cds_importer).to receive(:import).and_return inserted_oplog_records
    end

    it 'calls the CdsImporter import method', :aggregate_failures do
      cds_importer = instance_double(CdsImporter)
      allow(CdsImporter).to receive(:new).with(cds_update, staging_manager: instance_of(CdsImporter::StagingManager)).and_return(cds_importer)
      allow(cds_importer).to receive(:import).and_return inserted_oplog_records
      allow(TariffSynchronizer::Instrumentation).to receive(:file_import_completed)
      importer.import!

      expect(TariffSynchronizer::Instrumentation).to have_received(:file_import_completed)
      expect(CdsImporter).to have_received(:new).with(cds_update, staging_manager: instance_of(CdsImporter::StagingManager))
      expect(cds_importer).to have_received(:import)
    end

    it 'marks the Cds update as applied' do
      importer.import!
      expect(cds_update.reload).to be_applied
    end

    describe 'checking results of import' do
      let(:cds_importer) { instance_double(CdsImporter) }

      before do
        allow(CdsImporter).to receive(:new).with(cds_update, staging_manager: instance_of(CdsImporter::StagingManager)).and_return cds_importer
        allow(cds_importer).to receive(:import).and_return inserted_oplog_records
        allow(NewRelic::Agent).to receive(:notice_error)

        importer.import!
      end

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

        it 'alerts' do
          expect(NewRelic::Agent).to have_received(:notice_error)
                                       .with(/Empty CDS update - Issue Date: \d{4}-\d\d-\d\d: Applied: #{Time.zone.today}/)
        end
      end
    end
  end
end# frozen_string_literal: true

