RSpec.describe TariffSynchronizer::TaricUpdateImporter do
  let(:inserted_oplog_records) do
    {
      total_count: 1,
      total_duration: 0,
    }
  end

  describe '#import!' do
    let(:taric_update) { create :taric_update }
    let(:importer) { described_class.new(taric_update) }
    let(:taric_importer) { instance_double(TaricImporter, import: inserted_oplog_records) }

    before do
      allow(taric_update).to receive(:file_path).and_return('spec/fixtures/taric_samples/insert_record.xml')
      allow(TaricImporter).to receive(:new).with(taric_update).and_return(taric_importer)
    end

    it 'calls the TaricImporter import method', :aggregate_failures do
      allow(TariffSynchronizer::Instrumentation).to receive(:file_import_completed)

      importer.import!

      expect(TariffSynchronizer::Instrumentation).to have_received(:file_import_completed)
      expect(TaricImporter).to have_received(:new).with(taric_update)
      expect(taric_importer).to have_received(:import)
    end

    it 'marks the Taric update as applied' do
      importer.import!
      expect(taric_update.reload).to be_applied
    end

    it 'stores the inserts on the update' do
      importer.import!
      expect(taric_update.reload.inserts).to include('"total_count":1')
    end
  end
end
