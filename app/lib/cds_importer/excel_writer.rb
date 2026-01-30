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
      # sort_worksheets
      workbook.close

      if TradeTariffBackend.cds_updates_send_email && !@failed
        TariffSynchronizer::Mailer.cds_updates(xml_to_file_date, workbook, excel_filename).deliver_now
      end
    rescue StandardError => e
      Rails.logger.error "CDS Updates excel: save file error for #{@filename} - #{e.message}"
    end

    private

    attr_reader :workbook, :filename, :package, :bold_style, :regular_style

    def sort_worksheets
      CdsImporter::ExcelWriter.constants.each do |const|
        klass = CdsImporter::ExcelWriter.const_get(const)
        next unless klass.is_a?(Class)

        worksheet = workbook.get_worksheet_by_name(klass.sheet_name)
        sort_columns = klass.sort_columns
        next unless sort_columns.present? && worksheet

        start_index = klass.start_index
        row_count = worksheet.rows.count

        rows = worksheet.rows.map { |r| r.cells.map(&:value) }[start_index..]
        rows.sort_by! do |r|
          sort_columns.map { |col| r[col] }
        end

        row_count.downto(start_index) do |index|
          worksheet.rows.delete_at(index)
        end

        rows.each { |r| worksheet.append_row r }
      end
    end

    def write(key, instances)
      klass = Module.const_get("CdsImporter::ExcelWriter::#{key}")

      update = klass.new(instances)
      return unless update.valid?

      sheet_name = klass.sheet_name
      note = klass.note
      heading = klass.heading
      column_widths = klass.column_widths

      sheet = workbook.add_worksheet(sheet_name)

      if note.present?
        sheet.append_row(note, bold_style)
        sheet.merge_range(*merge_cells_length(klass, 1))
        sheet.append_row([])
        sheet.merge_range(*merge_cells_length(klass, 2))
      end

      sheet.append_row(heading, bold_style)

      column_widths.each_with_index do |width, index|
        sheet.set_column_width(index, width)
      end

      sheet.append_row(update.data_row, regular_style)
      sheet.column_widths(*column_widths)
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

    def merge_cells_length(klass, row)
      [col(klass.table_span[0]), row, col(klass.table_span[1]), row]
    end

    def col(cell)
      cell.ord - 'A'.ord
    end
  end
end
