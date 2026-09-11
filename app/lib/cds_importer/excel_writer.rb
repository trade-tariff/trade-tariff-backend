class CdsImporter
  class ExcelWriter
    SKIPPED_OPERATION = :skipped

    # Fired whenever the spreadsheet could not be built or could not be sent.
    # CdsUpdateNotificationWorker subscribes to this and fails its job, because there the
    # spreadsheet is the job's only output. The daily sync, which runs this writer alongside
    # the record inserter, deliberately does not: a broken report must not fail a data import
    # that otherwise succeeded.
    FAILURE_EVENT = 'cds_updates_excel_failed.cds_importer'.freeze

    delegate :instrument, to: ActiveSupport::Notifications

    def initialize(filename)
      @filename = filename
      @xml_element_id = nil
      @key = ''
      @instances = []
      @data = {}
      @failures = []
      @skipped_row_counts = Hash.new(0)
      initiate_excel_file
    end

    def process_record(cds_entity)
      unless @xml_element_id.nil? || @xml_element_id == cds_entity.element_id
        begin
          write_data(@key, @instances)
        rescue StandardError => e
          report_failure("write error for #{@key} in #{@filename}", exception: e)
        end
        @instances = []
      end

      @key = cds_entity.key
      @xml_element_id = cds_entity.element_id
      @instances << cds_entity.instance
    end

    def after_parse
      write_data(@key, @instances) unless @key.empty?
      build_worksheets(@data) unless @data.empty?

      workbook.close

      log_skipped_rows
      deliver_report
    rescue StandardError => e
      report_failure("save file error for #{@filename}", exception: e)
    end

  private

    attr_reader :workbook, :filename, :package, :bold_style, :regular_style

    def failed?
      @failures.any?
    end

    # Every failure ends up in three places that are actually watched in production: the logs,
    # New Relic (which the Sidekiq workers run) and an ActiveSupport notification the calling
    # worker turns into a dead job. The Slack ping is best effort only: the notifier is built
    # in config/initializers/slack_notifier.rb for production alone and SlackNotifierService
    # pings through `presence&.`, so it is a silent no-op everywhere else.
    def report_failure(message, exception: nil)
      full_message = "CDS Updates excel: #{message}"
      full_message += " - #{exception.message}" if exception
      @failures << full_message

      Rails.logger.error full_message
      NewRelic::Agent.notice_error(exception || full_message)
      notify_slack_app(full_message, @filename)
      instrument(FAILURE_EVENT, filename: @filename, message: full_message)
    end

    def deliver_report
      return unless TradeTariffBackend.cds_updates_send_email

      if failed?
        report_failure("report for #{@filename} not sent because #{@failures.size} earlier failure(s) left it incomplete")
        return
      end

      TariffSynchronizer::Mailer.cds_updates(xml_to_file_date, workbook.read_string, excel_filename).deliver_now
    rescue StandardError => e
      report_failure("delivery failed for #{excel_filename}", exception: e)
    end

    # An invalid row is a deliberate filter rather than an error (a goods nomenclature change
    # with no description, for example), so it is logged and counted but does not fail the
    # report. Counting rather than logging per row keeps a large file from flooding the logs.
    def log_skipped_rows
      @skipped_row_counts.each do |key, count|
        Rails.logger.warn "CDS Updates excel: dropped #{count} invalid #{key} row(s) from #{@filename}"
      end
    end

    def write_data(key, instances)
      klass = Module.const_get("CdsImporter::ExcelWriter::#{key}")

      update = klass.new(instances)

      unless update.valid?
        @skipped_row_counts[key] += 1
        return
      end

      unless @data.include?(key)
        @data[key] = []
      end

      @data[key].push(update.data_row)
    end

    def build_worksheets(data)
      data.each do |key, values|
        klass = Module.const_get("CdsImporter::ExcelWriter::#{key}")

        column_widths = klass.column_widths
        heading = klass.heading
        merge_range = klass.table_span
        note = klass.note
        sheet_name = klass.sheet_name
        sort_columns = klass.sort_columns

        sheet = workbook.add_worksheet(sheet_name)

        if note.present?
          sheet.append_row([])
          sheet.merge_range(0, 0, 0, column_index(merge_range[1]), note, bold_style)
          sheet.append_row([])
        end

        sheet.append_row(heading, bold_style)

        if sort_columns.present?
          values.sort_by! do |r|
            sort_columns.map { |col| r[col] }
          end
        end

        values.each do |row|
          sheet.append_row(row, regular_style)
        end

        column_widths.each_with_index do |width, index|
          sheet.set_column_width(index, width)
        end
      end
    end

    def initiate_excel_file
      if File.exist?(excel_filename)
        FileUtils.rm(excel_filename)
      end
      FileUtils.mkdir_p(File.join(TariffSynchronizer.root_path, 'cds_updates'))
      @workbook = FastExcel.open(excel_filename, constant_memory: true)

      @bold_style = workbook.add_format(
        bg_color: 0xE3E5E6,
        bold: true,
        font_name: 'Calibri',
        font_size: 11,
      )

      @regular_style = workbook.add_format(
        align: { h: :left, v: :top },
        font_name: 'Arial',
        font_size: 11,
        text_wrap: true,
      )
    end

    def excel_filename
      File.join(TariffSynchronizer.root_path, 'cds_updates', "CDS updates #{xml_to_file_date}.xlsx")
    end

    def xml_to_file_date
      if filename =~ /(\d{8})T/
        raw_date = Regexp.last_match(1)
        year  = raw_date[0, 4]
        month = raw_date[4, 2]
        day   = raw_date[6, 2]

        "#{year}-#{month}-#{day}"
      else
        ''
      end
    end

    def column_index(col)
      (col.ord - 'A'.ord).to_i
    end

    def notify_slack_app(message, filename)
      SlackNotifierService.call("Warn: CDS Updates report failed for #{filename} - #{message}")
    end
  end
end
