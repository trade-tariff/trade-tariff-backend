require 'rails_helper'

# rubocop:disable RSpec/AnyInstance
describe CdsImporter do
  subject(:importer) { described_class.new(cds_update) }

  let(:cds_update) { TariffSynchronizer::CdsUpdate.new(filename: 'tariff_dailyExtract_v1_20201004T235959.gzip') }

  around do |example|
    FileUtils.mkpath('tmp/data/cds')
    FileUtils.cp('spec/fixtures/cds_samples/tariff_dailyExtract_v1_20201004T235959.gzip', 'tmp/data/cds/tariff_dailyExtract_v1_20201004T235959.gzip')
    example.call
    FileUtils.rm_rf('tmp/data/cds')
  end

  before do
    allow(described_class::XmlProcessor).to receive(:new).and_call_original
  end

  describe '#import' do
    it 'creates new instance of XmlProcessor' do
      importer.import
      expect(described_class::XmlProcessor).to have_received(:new)
    end

    it 'invokes CdsImporter::XmlParser::Reader' do
      expect_any_instance_of(described_class::XmlParser::Reader).to receive(:parse)
      importer.import
    end
  end

  describe 'XmlProcessor' do
    let(:processor) { described_class::XmlProcessor.new(cds_update.filename) }

    it 'calls the EntityMapper with the correct arguments' do
      allow(described_class::EntityMapper).to receive(:new).and_return(instance_double(described_class::EntityMapper, import: nil))

      processor.process_xml_node('AdditionalCode', {})

      expect(described_class::EntityMapper).to have_received(:new).with('AdditionalCode', 'filename' => cds_update.filename)
    end

    it 'invokes EntityMapper' do
      expect_any_instance_of(described_class::EntityMapper).to receive(:import)
      processor.process_xml_node('AdditionalCode', {})
    end

    context 'when some error appears' do
      before do
        allow_any_instance_of(described_class::EntityMapper).to receive(:import).and_raise(StandardError)
      end

      it 'raises ImportException' do
        expect { processor.process_xml_node('AdditionalCode', {}) }.to raise_error(described_class::ImportException)
      end
    end
  end
end
# rubocop:enable RSpec/AnyInstance
