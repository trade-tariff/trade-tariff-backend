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
      sort_worksheets
      FileUtils.mkdir_p(File.join(TariffSynchronizer.root_path, 'cds_updates'))
      package.serialize(File.join(TariffSynchronizer.root_path, 'cds_updates', excel_filename))
      if TradeTariffBackend.cds_updates_send_email && !@failed
        TariffSynchronizer::Mailer.cds_updates(xml_to_file_date, package, excel_filename).deliver_now
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

        worksheet = workbook.worksheets.find { |ws| ws.name == klass.sheet_name }
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

        rows.each { |r| worksheet.add_row r }
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


      sheet = workbook.worksheets.find { |ws| ws.name == sheet_name }
      unless sheet
        sheet = workbook.add_worksheet(name: sheet_name)

        if note.present?
          sheet.add_row(note, style: bold_style)
          sheet.merge_cells(merge_cells_length(klass, 1))
          sheet.add_row
          sheet.merge_cells(merge_cells_length(klass, 2))
        end

        sheet.add_row(heading, style: bold_style)
        sheet.column_widths(*column_widths)
      end

      sheet.add_row(update.data_row, style: regular_style)
      sheet.column_widths(*column_widths)
    rescue StandardError => e
      Rails.logger.info "Write record error on #{key} - #{e.message}"
    end

    def initiate_excel_file
      @package = Axlsx::Package.new
      @workbook = package.workbook
      @bold_style = workbook.styles.add_style(
        b: true,
        font_name: 'Calibri',
        sz: 11,
        bg_color: 'e3e5e6',
      )
      @regular_style = workbook.styles.add_style(
        alignment: {
          wrap_text: true,
          horizontal: :left,
          vertical: :top,
        },
        font_name: 'Calibri',
        sz: 11,
      )
    end

    def excel_filename
      "CDS updates #{xml_to_file_date}.xlsx"
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
      "#{klass.table_span[0]}#{row}:#{klass.table_span[1]}#{row}"
    end
  end
end
