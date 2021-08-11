require 'zip'
# It's important to require mappers before xml_parser and entity_mapper to load all descendants
Dir[Rails.root.join('lib/cds_importer/entity_mapper/*.rb')].sort.each { |f| require f }
require 'cds_importer/xml_parser'
require 'cds_importer/entity_mapper'

class CdsImporter
  class ImportException < StandardError
    attr_reader :original

    def initialize(msg = 'CdsImporter::ImportException', original = $ERROR_INFO)
      super(msg)
      @original = original
    end
  end

  class UnknownOperationError < ImportException
  end

  def initialize(cds_update)
    @cds_update = cds_update
  end

  def import
    handler = XmlProcessor.new(@cds_update.filename)
    zip_file = TariffSynchronizer::FileService.file_as_stringio(@cds_update)

    Zip::File.open_buffer(zip_file) do |archive|
      archive.entries.each do |entry|
        # Read into memory
        xml_stream = entry.get_input_stream
        # do the xml parsing depending on records root depth
        CdsImporter::XmlParser::Reader.new(xml_stream.read, handler).parse

        ActiveSupport::Notifications.instrument('cds_imported.tariff_importer', filename: @cds_update.filename)
      end
    end
  end

  class XmlProcessor
    def initialize(filename)
      @filename = filename
    end

    def process_xml_node(key, hash_from_node)
      hash_from_node['filename'] = @filename
      CdsImporter::EntityMapper.new(key, hash_from_node).import
    rescue StandardError => e
      ActiveSupport::Notifications.instrument(
        'cds_failed.tariff_importer',
        exception: e, hash: hash_from_node, key: key,
      )
      raise ImportException
    end
  end
end
