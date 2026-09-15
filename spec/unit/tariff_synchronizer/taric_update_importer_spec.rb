RSpec.describe TariffSynchronizer::TaricUpdateImporter do
  def inserted_oplog_records(total_count)
    {
      total_count: total_count,
      total_duration: 0,
      total_allocations: 0,
    }
  end

  describe '#import!' do
    let(:taric_update) { create :taric_update }

    before do
      allow(taric_update).to receive(:file_path).and_return('spec/fixtures/taric_samples/insert_record.xml')

      taric_importer = instance_double(TaricImporter)
      allow(TaricImporter).to receive(:new).with(taric_update, staging_manager: instance_of(TariffSynchronizer::StagingManager)).and_return(taric_importer)
      allow(taric_importer).to receive(:import).and_return inserted_oplog_records(3)
    end

    it 'calls the TaricImporter import method', :aggregate_failures do
      taric_importer = instance_double(TaricImporter)
      allow(TaricImporter).to receive(:new).with(taric_update, staging_manager: instance_of(TariffSynchronizer::StagingManager)).and_return(taric_importer)
      allow(taric_importer).to receive(:import).and_return inserted_oplog_records(3)
      allow(TariffSynchronizer::Instrumentation).to receive(:file_import_completed)
      described_class.new(taric_update).import!

      expect(TariffSynchronizer::Instrumentation).to have_received(:file_import_completed)
      expect(TaricImporter).to have_received(:new).with(taric_update, staging_manager: instance_of(TariffSynchronizer::StagingManager))
      expect(taric_importer).to have_received(:import)
    end

    it 'marks the Taric update as applied' do
      described_class.new(taric_update).import!
      expect(taric_update.reload).to be_applied
    end

    describe 'checking results of import' do
      let(:taric_importer) { instance_double(TaricImporter) }

      before do
        allow(TaricImporter).to receive(:new).with(taric_update, staging_manager: instance_of(TariffSynchronizer::StagingManager)).and_return taric_importer
        allow(taric_importer).to receive(:import).and_return inserted_oplog_records(1)
        allow(NewRelic::Agent).to receive(:notice_error)

        described_class.new(taric_update).import!
      end

      context 'with valid upload' do
        before do
          allow(TaricImporter).to receive(:new).with(taric_update, staging_manager: instance_of(TariffSynchronizer::StagingManager)).and_return taric_importer
          allow(taric_importer).to receive(:import).and_return inserted_oplog_records(1)
          allow(NewRelic::Agent).to receive(:notice_error)
        end

        it 'stores the inserts on the update' do
          expect(taric_update.reload.inserts).to include('"total_count":1')
        end

        it 'does not alert' do
          expect(NewRelic::Agent).not_to have_received(:notice_error)
        end
      end
    end

    describe 'with empty results of import' do
      let(:taric_importer) { instance_double(TaricImporter) }

      before do
        allow(TaricImporter).to receive(:new).with(taric_update, staging_manager: instance_of(TariffSynchronizer::StagingManager)).and_return taric_importer
        allow(taric_importer).to receive(:import).and_return inserted_oplog_records(0)
        allow(NewRelic::Agent).to receive(:notice_error)
      end

      context 'with empty upload' do
        before do
          allow(taric_update).to receive(:filesize).and_return(477)

          described_class.new(taric_update).import!
        end

        it 'alert' do
          expect(NewRelic::Agent).to have_received(:notice_error)
                                       .with(/Empty TARIC update - Issue Date: \d{4}-\d\d-\d\d: Applied: #{Time.zone.today}/)
        end
      end

      context 'with missing inserts' do
        before do
          described_class.new(taric_update).import!
        end

        it 'alerts' do
          expect(NewRelic::Agent).to have_received(:notice_error)
                                       .with(/Empty TARIC update - Issue Date: \d{4}-\d\d-\d\d: Applied: #{Time.zone.today}/)
        end
      end
    end
  end
end
