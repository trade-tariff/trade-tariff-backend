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
  end

  def import
    handler = XmlProcessor.new(@taric_update.issue_date)

    file = TariffSynchronizer::FileService.file_as_stringio(@taric_update)
    XmlParser::Reader.new(file, 'record', handler).parse

    Rails.logger.info "Successfully imported Taric file: #{@taric_update.filename}"
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
end
