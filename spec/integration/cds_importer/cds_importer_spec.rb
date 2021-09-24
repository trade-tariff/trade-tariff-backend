RSpec.describe CdsImporter do
  let(:cds_update) { TariffSynchronizer::CdsUpdate.new(filename: 'tariff_dailyExtract_v1_20201004T235959.gzip') }
  let(:importer) { CdsImporter.new(cds_update) }

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
  end

  describe 'XmlProcessor' do
    let(:processor) { CdsImporter::XmlProcessor.new(cds_update.filename) }

    it 'invokes EntityMapper' do
      expect(CdsImporter::EntityMapper).to receive(:new).with('AdditionalCode', { 'filename' => cds_update.filename }).and_call_original
      expect_any_instance_of(CdsImporter::EntityMapper).to receive(:import)
      processor.process_xml_node('AdditionalCode', {})
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
