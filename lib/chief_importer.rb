require 'tariff_importer/logger'
require 'chief_importer/entry'
require 'chief_importer/start_entry'
require 'chief_importer/end_entry'
require 'chief_importer/change_entry'
require 'chief_importer/strategies/base_strategy'
require 'chief_importer/strategies/comm'
require 'chief_importer/strategies/mfcm'
require 'chief_importer/strategies/tame'
require 'chief_importer/strategies/tamf'
require 'chief_importer/strategies/tbl9'

class ChiefImporter
  class ImportException < StandardError
    attr_reader :original

    def initialize(msg = 'ChiefImporter::ImportException', original = $!)
      super(msg)
      @original = original
    end
  end

  cattr_accessor :relevant_tables
  self.relevant_tables = %w(MFCM TAMF TAME COMM TBL9)

  cattr_accessor :start_mark
  self.start_mark = 'AAAAAAAAAAA'

  cattr_accessor :end_mark
  self.end_mark = 'ZZZZZZZZZZZ'

  attr_reader :processor, :start_entry, :end_entry

  delegate :extraction_date, to: :start_entry, allow_nil: true
  delegate :record_count, to: :end_entry, allow_nil: true

  def initialize(chief_update)
    @chief_update = chief_update
  end

  def import
    file = TariffSynchronizer::FileService.file_as_stringio(@chief_update)
    file.set_encoding('ISO-8859-1')
    CSV.parse(file) do |line|
      entry = Entry.build(line)

      if entry.is_a?(StartEntry)
        @start_entry = entry
      elsif entry.is_a?(EndEntry)
        @end_entry = entry
      else # means it's ChangeEntry
        next unless entry.relevant?
        entry.origin = @chief_update.filename
        entry.process!
      end
    end
    ActiveSupport::Notifications.instrument('chief_imported.tariff_importer',
      filename: @chief_update.filename, count: record_count)
  rescue => exception
    ActiveSupport::Notifications.instrument('chief_failed.tariff_importer',
      filename: @chief_update.filename, exception: exception)
    raise ImportException.new(exception.message, exception)
  end
end
