RSpec.describe CdsImporter do
  # This xml file is empty
  let(:cds_update) { TariffSynchronizer::CdsUpdate.new(filename: 'tariff_dailyExtract_v1_20201004T235959.gzip') }
  let(:importer) { described_class.new(cds_update) }

  before(:all) do
    FileUtils.rm_rf('tmp/data/cds')
    FileUtils.mkpath('tmp/data/cds')
    FileUtils.cp_r('spec/fixtures/cds_samples/.', 'tmp/data/cds')
  end

  describe '#import' do
    it 'creates new instance of XmlProcessor' do
      expect(CdsImporter::XmlProcessor).to receive(:new).and_call_original
      importer.import
    end

    it 'invokes CdsImporter::XmlParser::Reader' do
      expect_any_instance_of(CdsImporter::XmlParser::Reader).to receive(:parse)
      importer.import
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

    context 'when importing a footnote with a ridiculous description' do
      let(:cds_update) { TariffSynchronizer::CdsUpdate.new(filename: 'footnote.gzip') }

      before do
        allow_any_instance_of(CdsImporter::EntityMapper).to receive(:import).and_call_original
      end

      it 'creates a footnote with a large description' do
        expect { importer.import }.to change(Footnote, :count).by(1)

        # expect(Footnote.where(footnote_id: '1234567890').first.description).to eq('A' * 1000)
      end

      it 'does not raise an error' do
        expect { importer.import }.not_to raise_error
      end
    end
  end

  describe 'XmlProcessor' do
    let(:processor) { CdsImporter::XmlProcessor.new(cds_update.filename) }

    context 'with valid import file' do
      it 'invokes EntityMapper' do
        allow(CdsImporter::EntityMapper).to receive(:new).with('AdditionalCode', { 'filename' => cds_update.filename }).and_call_original

        expect_any_instance_of(CdsImporter::EntityMapper).to receive(:import).and_call_original

        processor.process_xml_node('AdditionalCode', {})
      end
    end

    context 'when some error appears' do
      before do
        allow_any_instance_of(CdsImporter::EntityMapper).to receive(:import).and_raise(StandardError)
      end

      it 'raises ImportException' do
        expect { processor.process_xml_node('AdditionalCode', {}) }.to raise_error(CdsImporter::ImportException)
      end
    end
  end
end
