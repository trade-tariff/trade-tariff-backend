class TariffChangesService
  class ExcelGenerator
    def self.call(change_records, date)
      return if change_records.empty?

      new(change_records, date).call
    end

    attr_accessor :change_records, :date, :workbook

    def initialize(change_records, date)
      @change_records = change_records
      @date = date
    end

    def call
      @workbook = if Rails.env.development?
                    FileUtils.rm(filename) if File.exist?(filename)
                    FastExcel.open(filename, constant_memory: true)
                  else
                    FastExcel.open(constant_memory: true)
                  end

      worksheet = workbook.add_worksheet('Commodity watch list')
      add_headers(worksheet)
      stream_data_rows(worksheet)
      set_column_widths(worksheet)

      workbook
    end

    private

    def add_headers(sheet)
      # Title row
      sheet.append_row(['Changes to your commodity watch list'], cell_styles[:title])
      sheet.set_row(sheet.last_row_number, 40, nil)

      # Subtitle row
      sheet.append_row(["Published #{date}"], cell_styles[:subtitle])
      sheet.set_row(sheet.last_row_number, 25, nil)

      # Empty row
      sheet.append_row([])
      sheet.set_row(sheet.last_row_number, 20, nil)

      # Pre-header row
      sheet.append_row([])
      sheet.merge_range(3, 0, 3, 3, 'Is this change relevant to your business (useful filters)', cell_styles[:pre_header])
      sheet.merge_range(3, 4, 3, 6, 'Impacted Commodity details', cell_styles[:pre_header])
      sheet.merge_range(3, 7, 3, 9, 'Change details', cell_styles[:pre_header])
      sheet.merge_range(3, 10, 3, 11, 'Useful Links', cell_styles[:pre_header])
      sheet.set_row(sheet.last_row_number, 40, nil)

      # Header row
      header_styles = [cell_styles[:header]] * 12
      sheet.append_row(excel_header_row, header_styles)
      sheet.set_row(sheet.last_row_number, 40, nil)

      # Autofilter
      header_row = 4
      last_data_row = header_row + @change_records.length
      last_col = excel_header_row.size - 1
      sheet.autofilter(header_row, 0, last_data_row, last_col)
    end

    def stream_data_rows(sheet)
      @change_records.each_slice(100) do |batch|
        batch.each do |record|
          sheet.append_row(
            build_excel_row(record),
            build_row_styles,
          )

          add_hyperlinks(sheet, sheet.last_row_number, record)
        end
      end
    end

    def set_column_widths(sheet)
      excel_column_widths.each_with_index do |width, index|
        sheet.set_column_width(index, width)
      end
    end

    def excel_header_row
      [
        'Import/Export (if applicable)',
        'Impacted Geographical area (if applicable)',
        'Impacted Measure (if applicable)',
        'Additional Code (if applicable)',
        'Chapter',
        'Commodity Code',
        'Commodity Code description',
        'Change Type',
        'Change Detail',
        'Change Date of Effect',
        'View OTT for Change Date of Effect',
        'API call for the changed Commodity',
      ]
    end

    def excel_column_widths
      [
        20,  # Import/Export
        30,  # Geo Area
        30,  # Measure
        30,  # Additional Code
        15,  # Chapter
        20,  # Commodity Code
        50,  # Commodity Description
        30,  # Change type
        30,  # Change detail
        22,  # Date of effect
        80,  # OTT Link
        60,  # API Link
      ]
    end

    def cell_styles
      @cell_styles ||= {
        title: workbook.add_format(
          bold: true,
          font_size: 24,
        ),
        subtitle: workbook.add_format(
          font_size: 16,
        ),
        pre_header: workbook.add_format(
          align: { h: :left, v: :center },
          bg_color: 0x215C98,
          bold: true,
          border: :border_thin,
          font_color: 0xFFFFFF,
          font_size: 16,
          text_wrap: true,
        ),
        header: workbook.add_format(
          align: { h: :left, v: :center },
          bg_color: 0x4F81BD,
          bold: true,
          font_color: 0xFFFFFF,
          text_wrap: true,
        ),
        date: workbook.add_format(
          align: { h: :center, v: :center },
          border: :border_thin,
          top_color: 0xD3D3D3,
          bottom_color: 0xD3D3D3,
          left_color: 0xD3D3D3,
          right_color: 0xD3D3D3,
          num_format: '14',
        ),
        commodity_code: workbook.add_format(
          align: { h: :center, v: :center },
          border: :border_thin,
          top_color: 0xD3D3D3,
          bottom_color: 0xD3D3D3,
          left_color: 0xD3D3D3,
          right_color: 0xD3D3D3,
          num_format: '0000000000',
        ),
        chapter: workbook.add_format(
          align: { h: :center, v: :center },
          border: :border_thin,
          top_color: 0xD3D3D3,
          bottom_color: 0xD3D3D3,
          left_color: 0xD3D3D3,
          right_color: 0xD3D3D3,
          num_format: '00',
        ),
        text: workbook.add_format(
          align: { h: :left, v: :center },
          border: :border_thin,
          top_color: 0xD3D3D3,
          bottom_color: 0xD3D3D3,
          left_color: 0xD3D3D3,
          right_color: 0xD3D3D3,
          text_wrap: true,
        ),
        center_text: workbook.add_format(
          align: { h: :center, v: :center },
          border: :border_thin,
          top_color: 0xD3D3D3,
          bottom_color: 0xD3D3D3,
          left_color: 0xD3D3D3,
          right_color: 0xD3D3D3,
        ),
        hyperlink: workbook.add_format(
          align: { h: :left, v: :center },
          border: :border_thin,
          font_color: 0x0563C1,
          text_wrap: true,
          underline: :underline_single,
        ),
        bold_text: workbook.add_format(
          align: { h: :left, v: :center },
          bold: true,
          border: :border_thin,
          text_wrap: true,
        ),
      }
    end

    def build_row_styles
      [
        cell_styles[:text],           # Import/Export
        cell_styles[:text],           # Geo Area
        cell_styles[:text],           # Measure Type
        cell_styles[:text],           # Additional Code
        cell_styles[:chapter],        # Chapter
        cell_styles[:commodity_code], # Commodity Code
        cell_styles[:text],           # Commodity Description
        cell_styles[:bold_text],      # Type of Change
        cell_styles[:text],           # Change detail
        cell_styles[:date],           # Date of effect
        cell_styles[:hyperlink],      # OTT Link
        cell_styles[:hyperlink],      # API Link
      ]
    end

    def build_excel_row(record)
      [
        record[:import_export],
        record[:geo_area],
        record[:measure_type],
        record[:additional_code],
        record[:chapter],
        record[:commodity_code],
        record[:commodity_code_description],
        record[:type_of_change],
        record[:change_detail],
        record[:date_of_effect],
        record[:ott_url],
        record[:api_url],
      ]
    end

    def add_hyperlinks(sheet, row, record)
      sheet.write_url(row, 10, record[:ott_url], cell_styles[:hyperlink]) if record[:ott_url]
      sheet.write_url(row, 11, record[:api_url], cell_styles[:hyperlink]) if record[:api_url]
    end

    def filename
      "commodity_watch_list_changes_#{date}.xlsx"
    end
  end
end
