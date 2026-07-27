require 'nokogiri'

require 'taric_importer/xml_parser'
require 'taric_importer/entity_mapper'
require 'taric_importer/record_inserter'
require 'taric_importer/national_sid_counter'

class TaricImporter
  class ImportException < StandardError
    attr_reader :original

    def initialize(msg = 'TaricImporter::ImportException', original = $ERROR_INFO)
      super(msg)
      @original = original
    end
  end

  class UnknownOperationError < ImportException
  end

  DEFAULT_HANDLER_CLASSES = [
    TaricImporter::RecordInserter,
  ].freeze

  def initialize(taric_update, handler_classes: DEFAULT_HANDLER_CLASSES, staging_manager: nil)
    @taric_update = taric_update
    @handler_classes = handler_classes
    @staging_manager = staging_manager
    @oplog_inserts = {
      operations: {
        create: { count: 0, duration: 0 },
        update: { count: 0, duration: 0 },
        destroy: { count: 0, duration: 0 },
        skipped: { count: 0, duration: 0 },
      },
      total_count: 0,
      total_duration: 0,
    }
  end

  def import
    subscription = nil
    filename = determine_filename(@taric_update.file_path)
    return unless proceed_with_import?(filename)

    subscription = subscribe_to_oplog_inserts
    handlers = @handler_classes.map do |handler_class|
      handler_class.new(filename, staging_manager: @staging_manager)
    end
    handler = XmlProcessor.new(@taric_update.issue_date, handlers:, national_sid_counter: NationalSidCounter.new)
    file = TariffSynchronizer::FileService.file_as_stringio(@taric_update)
    TaricImporter::XmlParser::Reader.new(file, 'record', handler).parse
    handler.after_parse
    post_import(file_path: @taric_update.file_path, filename:)

    @oplog_inserts
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end

  class XmlProcessor
    def initialize(issue_date, handlers:, national_sid_counter:)
      @issue_date = issue_date
      @handlers = handlers
      @national_sid_counter = national_sid_counter
    end

    def process_xml_node(hash_from_node)
      EntityMapper
        .new(hash_from_node, issue_date: @issue_date, national_sid_counter: @national_sid_counter)
        .build do |entity|
        @handlers.each do |handler|
          handler.process_record(entity)
        end
      end
    rescue StandardError => e
      taric_failed_log(e, hash_from_node)
      raise ImportException
    end

    def after_parse
      @handlers.each(&:after_parse)
    end

  private

    def taric_failed_log(exception, hash)
      "Taric import failed: #{exception}".tap do |message|
        message << "\n Failed transaction:\n #{hash}"
        message << "\n Backtrace:\n #{exception.backtrace.join("\n")}"
        Rails.logger.error message
      end
    end
  end

  TaricEntity = Data.define(
    :element_id,
    :key,
    :instance,
    :mapper,
  )

private

  attr_reader :oplog_inserts

  def subscribe_to_oplog_inserts
    ActiveSupport::Notifications.subscribe('taric_importer.import.operations') do |*args|
      oplog_event = ActiveSupport::Notifications::Event.new(*args)

      count = oplog_event.payload[:count]
      if count.positive?
        duration = oplog_event.duration
        mapper = oplog_event.payload[:mapper]
        operation = oplog_event.payload[:operation]
        entity_class = mapper.entity_class

        oplog_inserts[:operations][operation][entity_class] ||= {}
        oplog_inserts[:operations][operation][entity_class][:count] ||= 0
        oplog_inserts[:operations][operation][entity_class][:duration] ||= 0
        oplog_inserts[:operations][operation][entity_class][:count] += count
        oplog_inserts[:operations][operation][entity_class][:duration] += duration

        oplog_inserts[:operations][operation][:count] += count
        oplog_inserts[:operations][operation][:duration] += duration

        oplog_inserts[:total_count] += count
        oplog_inserts[:total_duration] += duration
      end
    end
  end

  def proceed_with_import?(filename)
    return true unless TradeTariffBackend.uk?

    TariffSynchronizer::TaricUpdate.find(filename: filename[0, 30]).blank?
  end

  def post_import(file_path:, filename:)
    create_update_entry(file_path:, filename:) if TradeTariffBackend.uk?
    Rails.logger.info "Successfully imported Taric file: #{@taric_update.filename}"
  end

  def create_update_entry(file_path:, filename:)
    file_size = determine_file_size(file_path)
    issue_date = Date.parse(filename.scan(/[0-9]{8}/).last)
    TariffSynchronizer::TaricUpdate.find_or_create(
      filename: filename[0, 30],
      issue_date:,
      filesize: file_size,
      state: 'A',
      applied_at: Time.zone.now,
      updated_at: Time.zone.now,
    )
  end

  def determine_file_size(file_path)
    file_size = File.size(file_path)
    return file_size if file_size <= 214_748_364_7

    file_size / 1024
  end

  def determine_filename(file_path)
    File.basename(file_path)
  end
end
