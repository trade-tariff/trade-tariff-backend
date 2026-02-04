class CdsImporter
  class ExcelWriter
    SKIPPED_OPERATION = :skipped

    delegate :instrument, to: ActiveSupport::Notifications

    def initialize(filename)
      @filename = filename
      @xml_element_id = nil
      @key = ''
      @instances = []
      @failed = false
      initiate_excel_file
    end

    def process_record(cds_entity)
      unless @xml_element_id.nil? || @xml_element_id == cds_entity.element_id
        begin
          write(@key, @instances)
        rescue StandardError => e
          Rails.logger.error "CDS Updates excel: write error #{@key} in #{@filename} - #{e.message}"
          @failed = true
        end
        @instances = []
      end

      @key = cds_entity.key
      @xml_element_id = cds_entity.element_id
      @instances << cds_entity.instance
    end

    def after_parse
      write(@key, @instances)
      workbook.close

      if TradeTariffBackend.cds_updates_send_email && !@failed
        TariffSynchronizer::Mailer.cds_updates(xml_to_file_date, workbook, excel_filename).deliver_now
      end
    rescue StandardError => e
      Rails.logger.error "CDS Updates excel: save file error for #{@filename} - #{e.message}"
    end

    private

    attr_reader :workbook, :filename, :package, :bold_style, :regular_style

    def write(key, instances)
      klass = Module.const_get("CdsImporter::ExcelWriter::#{key}")

      update = klass.new(instances)
      return unless update.valid?

      sheet_name = klass.sheet_name
      note = klass.note
      heading = klass.heading
      column_widths = klass.column_widths
      sort_columns = klass.sort_columns
      row = update.data_row

      sheet = workbook.add_worksheet(sheet_name)

      if note.present?
        sheet.append_row(note, bold_style)
        sheet.merge_range(
          col(klass.table_span[0]), 1,
          col(klass.table_span[1]), 1
        )
        sheet.append_row([])
        sheet.merge_range(
          col(klass.table_span[0]), 2,
          col(klass.table_span[1]), 2
        )
      end

      sheet.append_row(heading, bold_style)

      column_widths.each_with_index do |width, index|
        sheet.set_column_width(index, width)
      end

      if sort_columns.present?
        row.sort_by! do |r|
          sort_columns.map { |col| r[col] }
        end
      end

      sheet.append_row(row, regular_style)
    rescue StandardError => e
      Rails.logger.info "Write record error on #{key} - #{e.message}"
    end

    def initiate_excel_file
      @workbook = if Rails.env.development?
                    FileUtils.rm(excel_filename) if File.exist?(excel_filename)
                    FileUtils.mkdir_p(File.join(TariffSynchronizer.root_path, 'cds_updates'))
                    FastExcel.open(excel_filename, constant_memory: true)
                  else
                    FastExcel.open(constant_memory: true)
                  end

      @bold_style = workbook.add_format(
        bg_color: 0xE3E5E6,
        bold: true,
        font_name: 'Calibri',
        font_size: 11,
      )

      @regular_style = workbook.add_format(
        align: { h: :left, v: :top },
        font_name: 'Calibri',
        font_size: 11,
        text_wrap: true,
      )
    end

    def excel_filename
      if Rails.env.production?
        File.join(TariffSynchronizer.root_path, 'cds_updates', "CDS updates #{xml_to_file_date}.xlsx")
      else
        "CDS updates #{xml_to_file_date}.xlsx"
      end
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

    def col(cell)
      cell.ord - 'A'.ord
    end
  end
end
