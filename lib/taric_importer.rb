require 'nokogiri'

require 'tariff_importer/logger'
require 'taric_importer/transaction'
require 'taric_importer/record_processor'
require 'taric_importer/xml_parser'
require 'taric_importer/helpers/string_helper'

class TaricImporter
  class ImportException < StandardError
    attr_reader :original

    def initialize(msg = "TaricImporter::ImportException", original=$!)
      super(msg)
      @original = original
    end
  end

  class UnknownOperationError < ImportException
  end

  def initialize(taric_update)
    @taric_update = taric_update
  end

  def import(validate: true)
    filename = determine_filename(@taric_update.file_path)
    return unless proceed_with_import?(filename)

    handler = XmlProcessor.new(@taric_update.issue_date, validate)
    file = TariffSynchronizer::FileService.file_as_stringio(@taric_update)
    XmlParser::Reader.new(file, "record", handler).parse
    post_import(file_path: @taric_update.file_path, filename: filename)
  end

  class XmlProcessor
    def initialize(issue_date, validate)
      @issue_date = issue_date
      @validate = validate
    end

    def process_xml_node(hash_from_node)
      begin
        transaction = Transaction.new(hash_from_node, @issue_date)
        transaction.persist
        transaction.validate if @validate
      rescue StandardError => exception
        ActiveSupport::Notifications.instrument("taric_failed.tariff_importer", exception: exception, hash: hash_from_node)
        raise ImportException.new
      end
    end
  end

  private

  def proceed_with_import?(filename)
    return true unless TradeTariffBackend.use_cds?

    !TariffSynchronizer::TaricUpdate.find(filename: filename[0, 30]).present?
  end

  def post_import(file_path:, filename:)
    create_update_entry(file_path: file_path, filename: filename) if TradeTariffBackend.use_cds?
    ActiveSupport::Notifications.instrument("taric_imported.tariff_importer", filename: @taric_update.filename)
  end

  def create_update_entry(file_path:, filename:)
    file_size = determine_file_size(file_path)
    issue_date = Date.parse(filename.scan(/[0-9]{8}/).last)
    TariffSynchronizer::TaricUpdate.find_or_create(
      filename: filename[0, 30],
      issue_date: issue_date,
      filesize: file_size,
      state: 'A',
      applied_at: Time.now,
      updated_at: Time.now
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
