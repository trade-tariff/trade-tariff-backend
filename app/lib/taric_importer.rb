require 'nokogiri'

require 'taric_importer/transaction'
require 'taric_importer/record_processor'
require 'taric_importer/xml_parser'

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

  def initialize(taric_update)
    @taric_update = taric_update
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
    @all_sqls = []
  end

  def import
    filename = determine_filename(@taric_update.file_path)
    return unless proceed_with_import?(filename)

    subscribe_to_oplog_inserts

    processor = XmlProcessor.new(@taric_update.issue_date)
    file = TariffSynchronizer::FileService.file_as_stringio(@taric_update)
    TaricImporter::XmlParser::Reader.new(file, 'record', processor).parse
    post_import(file_path: @taric_update.file_path, filename:)
    write_sql_to_file(filename:)
    @oplog_inserts
  end

  class XmlProcessor
    def initialize(issue_date)
      @issue_date = issue_date
    end

    def process_xml_node(hash_from_node)
      transaction = Transaction.new(hash_from_node, @issue_date)
      transaction.persist
    rescue StandardError => e
      taric_failed_log(e, hash_from_node)
      raise ImportException
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

  private

  attr_reader :oplog_inserts, :all_sqls

  def subscribe_to_oplog_inserts
    ActiveSupport::Notifications.subscribe('taric_importer.import.operations') do |*args|
      oplog_event = ActiveSupport::Notifications::Event.new(*args)

      count = oplog_event.payload[:count]
      if count.positive?
        duration = oplog_event.duration
        operation = oplog_event.payload[:operation]
        entity_class = oplog_event.payload[:entity_class]

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

      sql = oplog_event.payload[:sql]
      if sql.present?
        all_sqls << sql
      end
    end
  end

  def write_sql_to_file(filename:)
    sql_body = @all_sqls.map { |sql| "#{sql};" }.join("\n") + "\n"
    issue_date = filename.split('_').first
    sql_filename = "taric_#{issue_date}.sql"
    file_path = File.join(TariffSynchronizer.root_path, 'XI_CDS_Test', sql_filename)

    TariffSynchronizer::FileService.write_file(file_path, sql_body)
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
