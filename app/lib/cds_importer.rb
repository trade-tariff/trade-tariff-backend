require_relative 'cds_importer/entity_mapper'
require_relative 'cds_importer/xml_parser'

require 'zip'

class CdsImporter
  class ImportException < TariffSynchronizer::Import::Error
    DEFAULT_MESSAGE = 'CDS record import failed'.freeze

    def initialize(message: DEFAULT_MESSAGE, original: nil, context: {})
      super(message:, source: :cds, original:, context:)
    end
  end

  # Unlike TaricImporter::UnknownOperationError, this is never raised: CDS's EntityMapper
  # dispatches per record type via constant lookup rather than fetching an update_type, so
  # there's no unknown-operation code path here to wire it up to.
  class UnknownOperationError < ImportException
  end

  DEFAULT_HANDLER_CLASSES = [
    CdsImporter::RecordInserter,
    CdsImporter::ExcelWriter,
  ].freeze

  OPERATION_KEYS = %i[create update destroy destroy_missing skipped].freeze

  def initialize(cds_update, handler_classes: DEFAULT_HANDLER_CLASSES, staging_manager: nil)
    @cds_update = cds_update
    @handler_classes = handler_classes
    @staging_manager = staging_manager
    @tracker = TariffSynchronizer::Import::OperationTracker.new(operation_keys: OPERATION_KEYS)
  end

  def import
    zip_file = TariffSynchronizer::FileService.file_as_stringio(@cds_update)
    handlers = @handler_classes.map do |klass|
      if klass == CdsImporter::RecordInserter
        klass.new(@cds_update.filename, staging_manager: @staging_manager, tracker: @tracker)
      else
        klass.new(@cds_update.filename)
      end
    end
    handler = XmlProcessor.new(@cds_update.filename, handlers)

    Rails.logger.info "CDS Importer batch size: #{TradeTariffBackend.cds_importer_batch_size}"

    Zip::File.open_buffer(zip_file) do |archive|
      archive.entries.each do |entry|
        # Read into memory
        xml_stream = entry.get_input_stream
        # do the xml parsing depending on records root depth
        CdsImporter::XmlParser::Reader.new(xml_stream, handler).parse

        handler.after_parse
        Rails.logger.info "Successfully imported Cds file: #{@cds_update.filename}"
      end
    end

    @tracker.result
  end

  class XmlProcessor
    def initialize(filename, handlers = [])
      @filename = filename
      @handlers = handlers
    end

    def process_xml_node(key, hash_from_node)
      hash_from_node['filename'] = @filename

      CdsImporter::EntityMapper.new(key, hash_from_node).build do |cds_entity|
        @handlers.each do |handler|
          handler.process_record(cds_entity)
        end
      end
    rescue StandardError => e
      raise ImportException.new(
        original: e,
        context: { key:, transaction: hash_from_node },
      ), cause: e
    end

    def after_parse
      @handlers.each(&:after_parse)
    end
  end

  class CdsEntity
    def initialize(element_id, key, instance, mapper)
      @element_id = element_id
      @key = key
      @instance = instance
      @mapper = mapper
    end

    attr_reader :key, :instance, :mapper, :element_id
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

        oplog_inserts[:operations][operation][entity_class] ||= {}
        oplog_inserts[:operations][operation][entity_class][:count] ||= 0
        oplog_inserts[:operations][operation][entity_class][:duration] ||= 0
        oplog_inserts[:operations][operation][entity_class][:count] += count
        oplog_inserts[:operations][operation][entity_class][:duration] += duration
        oplog_inserts[:operations][operation][entity_class][:mapping_path] = mapping_path

        # We only accumulate skipped operations because we can work out from the file which record was inserted for non-missing operation types
        if [CdsImporter::RecordInserter::SKIPPED_OPERATION].include?(operation)
          record = oplog_event.payload[:record]

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
