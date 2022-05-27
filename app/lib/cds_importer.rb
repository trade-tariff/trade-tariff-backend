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
        create: { count: 0, duration: 0, allocations: 0 },
        update: { count: 0, duration: 0, allocations: 0 },
        destroy: { count: 0, duration: 0, allocations: 0 },
        destroy_cascade: { count: 0, duration: 0, allocations: 0 },
        destroy_missing: { count: 0, duration: 0, allocations: 0 },
      },
      total_count: 0,
      total_duration: 0,
      total_allocations: 0,
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
        CdsImporter::XmlParser::Reader.new(xml_stream.read, handler).parse

        ActiveSupport::Notifications.instrument('cds_imported.tariff_importer', filename: @cds_update.filename)
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
      ActiveSupport::Notifications.instrument(
        'cds_failed.tariff_importer',
        exception: e, hash: hash_from_node, key:,
      )
      raise ImportException
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
        allocations = oplog_event.allocations
        mapper = oplog_event.payload[:mapper]
        operation = oplog_event.payload[:operation]
        entity = mapper.entity_class
        mapping_path = mapper.mapping_path

        oplog_inserts[:operations][operation][entity] ||= {}
        oplog_inserts[:operations][operation][entity][:count] ||= 0
        oplog_inserts[:operations][operation][entity][:allocations] ||= 0
        oplog_inserts[:operations][operation][entity][:duration] ||= 0
        oplog_inserts[:operations][operation][entity][:count] += count
        oplog_inserts[:operations][operation][entity][:allocations] += allocations
        oplog_inserts[:operations][operation][entity][:duration] += duration
        oplog_inserts[:operations][operation][entity][:mapping_path] = mapping_path

        oplog_inserts[:operations][operation][:count] += count
        oplog_inserts[:operations][operation][:allocations] += allocations
        oplog_inserts[:operations][operation][:duration] += duration

        oplog_inserts[:total_count] += count
        oplog_inserts[:total_allocations] += allocations
        oplog_inserts[:total_duration] += duration
      end
    end
  end
end
