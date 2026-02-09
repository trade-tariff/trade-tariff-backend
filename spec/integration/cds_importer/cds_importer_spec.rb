RSpec.describe CdsImporter do
  subject(:importer) { described_class.new(cds_update) }

  # This xml file is empty
  let(:cds_update) { TariffSynchronizer::CdsUpdate.new(filename: 'tariff_dailyExtract_v1_20201004T235959.gzip') }

  after { FileUtils.rm_rf(File.join(TariffSynchronizer.root_path, 'cds_updates')) }

  describe '#build' do
    it 'creates new instance of XmlProcessor' do
      allow(CdsImporter::XmlProcessor).to receive(:new).and_call_original
      allow(CdsImporter::ExcelWriter).to receive(:new).with(cds_update.filename).and_call_original
      allow(CdsImporter::RecordInserter).to receive(:new).with(cds_update.filename).and_call_original

      importer.import
      expect(CdsImporter::XmlProcessor).to have_received(:new).with(cds_update.filename, kind_of(Array))
      expect(CdsImporter::RecordInserter).to have_received(:new)
      expect(CdsImporter::ExcelWriter).to have_received(:new)
    end

    it 'returns hash of inserted records' do
      expected_default_oplog_inserts = {
        operations: {
          create: { count: 0, duration: 0 },
          update: { count: 0, duration: 0 },
          destroy: { count: 0, duration: 0 },
          destroy_missing: { count: 0, duration: 0 },
          skipped: { count: 0, duration: 0 },
        },
        total_count: 0,
        total_duration: 0,
      }

      expect(importer.import).to eql(expected_default_oplog_inserts)
    end

    it 'subscribes to oplog events' do
      allow(ActiveSupport::Notifications).to receive(:subscribe).and_call_original

      importer.import

      expect(ActiveSupport::Notifications).to have_received(:subscribe).with('cds_importer.import.operations')
    end

    context 'when importing a footnote with a long description' do
      let(:cds_update) { TariffSynchronizer::CdsUpdate.new(filename: 'footnote.gzip') }

      it 'creates a footnote with a large description' do
        importer.import
        expect(Footnote.last.description.bytesize).to eq(5985)
      end
    end
  end

  describe 'XmlProcessor' do
    let(:db_handler) { CdsImporter::RecordInserter.new(cds_update.filename) }
    let(:excel_handler) { CdsImporter::ExcelWriter.new(cds_update.filename) }
    let(:processor) { CdsImporter::XmlProcessor.new(cds_update.filename, [db_handler, excel_handler]) }

    before do
      allow(db_handler).to receive(:process_record).and_call_original
      allow(excel_handler).to receive(:process_record).and_call_original
    end

    context 'with valid import file' do
      it 'invokes EntityMapper' do
        allow(CdsImporter::EntityMapper).to receive(:new).with('AdditionalCode', { 'filename' => cds_update.filename }).and_call_original

        processor.process_xml_node('AdditionalCode', {})

        expect(CdsImporter::EntityMapper).to have_received(:new)
        expect(db_handler).to have_received(:process_record)
        expect(excel_handler).to have_received(:process_record)
      end
    end

    context 'when some error appears' do
      before do
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(CdsImporter::EntityMapper).to receive(:build).and_raise(StandardError)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'raises ImportException' do
        expect { processor.process_xml_node('AdditionalCode', {}) }.to raise_error(CdsImporter::ImportException)
      end
    end
  end

  describe 'Excel writer' do
    let(:cds_update) { TariffSynchronizer::CdsUpdate.new(filename: 'tariff_dailyExtract_v1_20251006T125959.gzip') }
    let(:excel_filename) { 'CDS updates 2025-10-06.xlsx' }

    it 'creates CDS updates file' do
      importer.import
      expect(File).to exist(File.join(TariffSynchronizer.root_path, 'cds_updates', excel_filename))
    end
  end

  describe 'Excel writer errors handled and does not stop db updates' do
    let(:record_inserter) { instance_spy(CdsImporter::RecordInserter) }
    let(:excel_writer) { instance_spy(CdsImporter::ExcelWriter) }

    let(:processor) { CdsImporter::XmlProcessor.new(cds_update.filename, [excel_writer, record_inserter]) }

    before do
      # Excel writer fails when writing records
      allow(excel_writer).to receive(:write_data).and_raise(StandardError, 'Excel failed')

      allow(CdsImporter::EntityMapper).to receive(:new).with('AdditionalCode', { 'filename' => cds_update.filename }).and_call_original
    end

    it 'continues DB updates even if Excel writer raises error' do
      expect {
        processor.process_xml_node('AdditionalCode', {})
      }.not_to raise_error

      expect(record_inserter).to have_received(:process_record)
    end
  end
end
