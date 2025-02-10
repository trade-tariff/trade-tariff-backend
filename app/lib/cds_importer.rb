require_relative 'cds_importer/entity_mapper'
require_relative 'cds_importer/xml_parser'

require 'zip'

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
    @oplog_inserts = {
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
  end

  def import
    handler = XmlProcessor.new(@cds_update.filename)
    zip_file = TariffSynchronizer::FileService.file_as_stringio(@cds_update)

    subscribe_to_oplog_inserts

    Zip::File.open_buffer(zip_file) do |archive|
      archive.entries.each do |entry|
        # Read into memory
        xml_stream = entry.get_input_stream
        # do the xml parsing depending on records root depth
        CdsImporter::XmlParser::Reader.new(xml_stream, handler).parse
        Rails.logger.info "Successfully imported Cds file: #{@cds_update.filename}"
      end
    end

    @oplog_inserts
  end

  class XmlProcessor
    def initialize(filename)
      @filename = filename
    end

    def process_xml_node(key, hash_from_node)
      hash_from_node['filename'] = @filename

      CdsImporter::EntityMapper.new(key, hash_from_node).import
    rescue StandardError => e
      cds_failed_log(e, key, hash_from_node)
      raise ImportException
    end

    def cds_failed_log(exception, key, hash)
      "Cds import failed: #{exception}".tap do |message|
        message << "\n Failed object: #{key}\n #{hash}"
        message << "\n Backtrace:\n #{exception.backtrace.join("\n")}"
        Rails.logger.error message
      end
    end
  end

  private

  attr_reader :oplog_inserts

  def subscribe_to_oplog_inserts
    ActiveSupport::Notifications.subscribe('cds_importer.import.operations') do |*args|
      oplog_event = ActiveSupport::Notifications::Event.new(*args)

      count = oplog_event.payload[:count]

      if count.positive?
        duration = oplog_event.duration
        mapper = oplog_event.payload[:mapper]
        operation = oplog_event.payload[:operation]
        entity_class = mapper.entity_class
        mapping_path = mapper.mapping_path
        record = oplog_event.payload[:record]

        oplog_inserts[:operations][operation][entity_class] ||= {}
        oplog_inserts[:operations][operation][entity_class][:count] ||= 0
        oplog_inserts[:operations][operation][entity_class][:duration] ||= 0
        oplog_inserts[:operations][operation][entity_class][:count] += count
        oplog_inserts[:operations][operation][entity_class][:duration] += duration
        oplog_inserts[:operations][operation][entity_class][:mapping_path] = mapping_path

        # We only accumulate skipped operations because we can work out from the file which record was inserted for non-missing operation types
        if [CdsImporter::RecordInserter::SKIPPED_OPERATION].include?(operation)
          oplog_inserts[:operations][operation][entity_class][:records] ||= []
          oplog_inserts[:operations][operation][entity_class][:records] << record.identification
        end

        oplog_inserts[:operations][operation][:count] += count
        oplog_inserts[:operations][operation][:duration] += duration

        oplog_inserts[:total_count] += count
        oplog_inserts[:total_duration] += duration
      end
    end
  end
end
