RSpec.describe CdsImporter do
  subject(:importer) { described_class.new(cds_update) }

  # This xml file is empty
  let(:cds_update) { TariffSynchronizer::CdsUpdate.new(filename: 'tariff_dailyExtract_v1_20201004T235959.gzip') }

  describe '#import' do
    it 'creates new instance of XmlProcessor' do
      allow(CdsImporter::XmlProcessor).to receive(:new).and_call_original
      importer.import
      expect(CdsImporter::XmlProcessor).to have_received(:new).with(cds_update.filename)
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
    let(:processor) { CdsImporter::XmlProcessor.new(cds_update.filename) }

    context 'with valid import file' do
      it 'invokes EntityMapper' do
        allow(CdsImporter::EntityMapper).to receive(:new).with('AdditionalCode', { 'filename' => cds_update.filename }).and_call_original

        processor.process_xml_node('AdditionalCode', {})

        expect(CdsImporter::EntityMapper).to have_received(:new)
      end

      context 'when batch size is reached' do
        before do
          allow(TradeTariffBackend).to receive(:cds_importer_batch_size).and_return(1)
        end

        it 'invokes RecordInserter' do
          allow(CdsImporter::RecordInserter).to receive(:new).with(kind_of(Array), cds_update.filename).and_call_original

          processor.process_xml_node('AdditionalCode', {})

          expect(CdsImporter::RecordInserter).to have_received(:new)
        end
      end
    end

    context 'when some error appears' do
      before do
        # rubocop:disable RSpec/AnyInstance
        allow_any_instance_of(CdsImporter::EntityMapper).to receive(:import).and_raise(StandardError)
        # rubocop:enable RSpec/AnyInstance
      end

      it 'raises ImportException' do
        expect { processor.process_xml_node('AdditionalCode', {}) }.to raise_error(CdsImporter::ImportException)
      end
    end
  end
end
