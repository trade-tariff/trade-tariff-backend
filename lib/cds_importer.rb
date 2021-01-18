require 'mimemagic'
require 'zip'
# It's important to require mappers before xml_parser and entity_mapper to load all descendants
Dir[File.join(Rails.root, 'lib', 'cds_importer/entity_mapper/*.rb')].each { |f| require f }
require 'cds_importer/xml_parser'
require 'cds_importer/entity_mapper'

class CdsImporter
  class ImportException < StandardError
    attr_reader :original

    def initialize(msg = 'CdsImporter::ImportException', original=$!)
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
    gzip_file = TariffSynchronizer::FileService.file_as_stringio(@cds_update)

    # The api https://developer.service.hmrc.gov.uk/api-documentation/docs/api/service/secure-data-exchange-bulk-download/1.0
    # returns zip files for daily and monthly updates and gzip for annual files.
    if MimeMagic.by_magic(gzip_file).subtype == 'gzip'
      xml_stream = Zlib::GzipReader.wrap(gzip_file)

      CdsImporter::XmlParser::Reader.new(xml_stream, handler).parse

      ActiveSupport::Notifications.instrument('cds_imported.tariff_importer', filename: @cds_update.filename)
    else
      Zip::File.open_buffer(gzip_file) do |archive|
        archive.entries.each do |entry|
          # Read into memory
          xml_stream = entry.get_input_stream
          # do the xml parsing depending on records root depth
          CdsImporter::XmlParser::Reader.new(xml_stream.read, handler).parse

          ActiveSupport::Notifications.instrument('cds_imported.tariff_importer', filename: @cds_update.filename)
        end
      end
    end
  end

  class XmlProcessor
    def initialize(filename)
      @filename = filename
    end

    def process_xml_node(key, hash_from_node)
      begin
        hash_from_node['filename'] = @filename
        CdsImporter::EntityMapper.new(key, hash_from_node).import
      rescue StandardError => exception
        ActiveSupport::Notifications.instrument(
          'cds_failed.tariff_importer',
          exception: exception, hash: hash_from_node, key: key
        )
        raise ImportException.new
      end
    end
  end
end
