RSpec.describe CdsImporter do
  let(:cds_update) { TariffSynchronizer::CdsUpdate.new(filename: 'tariff_dailyExtract_v1_20201004T235959.gzip') }
  let(:importer) { described_class.new(cds_update) }

  before(:all) do
    FileUtils.mkpath('tmp/data/cds')
    FileUtils.cp('spec/fixtures/cds_samples/tariff_dailyExtract_v1_20201004T235959.gzip', 'tmp/data/cds/tariff_dailyExtract_v1_20201004T235959.gzip')
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
      expect(importer.import).to eql({})
    end
  end

  describe 'XmlProcessor' do
    let(:processor) { CdsImporter::XmlProcessor.new(cds_update.filename) }

    context 'with valid import file' do
      before do
        allow(CdsImporter::EntityMapper).to receive(:new).with('AdditionalCode', { 'filename' => cds_update.filename }).and_call_original
        allow_any_instance_of(CdsImporter::EntityMapper).to receive(:import).and_call_original
      end

      it 'invokes EntityMapper' do
        expect(processor.process_xml_node('AdditionalCode', {})).to eql({
          'AdditionalCode::Operation' => 1,
        })
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
