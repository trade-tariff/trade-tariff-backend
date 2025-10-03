class CdsImporter
  class ExcelWriter
    SKIPPED_OPERATION = :skipped

    delegate :instrument, to: ActiveSupport::Notifications

    def initialize(filename)
      @filename = filename
      @xml_element_id = nil
      @key = ''
      @instances = []
      create_excel_file
    end

    def write_record(cds_entity)
      unless @xml_element_id.nil? || @xml_element_id == cds_entity.element_id
        write(@key, @instances)
        @instances = []
      end

      @key = cds_entity.key
      @xml_element_id = cds_entity.element_id
      @instances << cds_entity.instance
    end

    def save_file
      FileUtils.mkdir_p(File.join(TariffSynchronizer.root_path, 'cds_updates'))
      package.serialize(File.join(TariffSynchronizer.root_path, 'cds_updates', excel_filename))
    end

    private

    attr_reader :workbook, :filename, :package, :bold_style, :regular_style

    def write(key, instances)
      begin
        update = Module.const_get("CdsImporter::ExcelWriter::#{key}").new(instances)
        sheet_name = update.sheet_name
        note = update.note

        sheet = workbook.worksheets.find { |ws| ws.name == sheet_name }
        unless sheet
          sheet = workbook.add_worksheet(name: sheet_name)

          if note.present?
            sheet.add_row(note, style: bold_style)
            sheet.merge_cells(merge_cells_length(update, 1))
            sheet.add_row
            sheet.merge_cells(merge_cells_length(update, 2))
          end

          sheet.add_row(update.heading, style: bold_style)
          sheet.column_widths(*update.column_widths)
        end

        sheet.add_row(update.data_row, style: regular_style)
        sheet.column_widths(*update.column_widths)
      rescue NameError
        Rails.logger.info "#{key} element is not mapped into CDS Updates"
      end
    end

    def create_excel_file
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

    def merge_cells_length(update, row)
      "#{update.table_span[0]}#{row}:#{update.table_span[1]}#{row}"
    end
  end
end
