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
      @workbook = FastExcel.open
      sheet = workbook.add_worksheet('Commodity watch list')

      set_column_widths(sheet)
      add_headers(sheet)
      stream_data_rows(sheet)
      add_table_styling(sheet)

      workbook
    end

    private

    def add_headers(sheet)
      sheet.append_row(['Changes to your commodity watch list'], cell_styles[:title])
      sheet.set_row(0, 40, cell_styles[:title])

      sheet.append_row(["Published #{date}"], cell_styles[:subtitle])
      sheet.set_row(1, 25, cell_styles[:subtitle])

      sheet.append_row([''])
      sheet.write_blank(2, 0, workbook.add_format)
      sheet.set_row(2, 20, nil)

      sheet.append_row(
        ['Is this change relevant to your business (useful filters)', '', '', '', '', 'Impacted Commodity details', '', '', 'Change details', '', '', 'Useful Links', ''],
        cell_styles[:pre_header],
      )
      sheet.set_row(3, 40, cell_styles[:pre_header])
      sheet.merge_range(3, 0, 3, 4, 'Is this change relevant to your business (useful filters)', cell_styles[:pre_header])
      sheet.merge_range(3, 5, 3, 7, 'Impacted Commodity details', cell_styles[:pre_header])
      sheet.merge_range(3, 8, 3, 10, 'Change details', cell_styles[:pre_header])
      sheet.merge_range(3, 11, 3, 12, 'Useful Links', cell_styles[:pre_header])

      sheet.append_row(excel_header_row, cell_styles[:header])
      sheet.set_row(4, 40, cell_styles[:header])
    end

    def stream_data_rows(sheet)
      @change_records.each_slice(100) do |batch|
        batch.each do |record|
          sheet.append_row(
            build_excel_row(record),
            build_row_styles,
          )
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
        'Quota order number (if applicable)',
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
        25,  # Quota order number
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
        title: workbook.add_format(bold: true, font_size: 24),
        subtitle: workbook.add_format(font_size: 16),
        pre_header: workbook.add_format(
          bold: true,
          bg_color: 0x215c98,
          font_color: 0xffffff,
          border: :border_thin,
          align: { h: :left, v: :center },
          text_wrap: true,
          font_size: 16,
        ),
        header: workbook.add_format(
          bold: true,
          align: { h: :left, v: :center },
          text_wrap: true,
        ),
        date: workbook.add_format(
          num_format: 'yyyy-mm-dd',
          border: :border_thin,
          align: { h: :center, v: :center },
        ),
        commodity_code: workbook.add_format(
          num_format: '0000000000',
          border: :border_thin,
          align: { h: :center, v: :center },
        ),
        chapter: workbook.add_format(
          num_format: '00',
          border: :border_thin,
          align: { h: :center, v: :center },
        ),
        text: workbook.add_format(
          border: :border_thin,
          align: { h: :left, v: :center },
          text_wrap: true,
        ),
        center_text: workbook.add_format(
          border: :border_thin,
          align: { h: :center, v: :center },
        ),
        hyperlink: workbook.add_format(
          font_color: 0x0563C1,
          underline: :underline_single,
          border: :border_thin,
          align: { h: :left, v: :center },
          text_wrap: true,
        ),
        bold_text: workbook.add_format(
          bold: true,
          border: :border_thin,
          align: { h: :left, v: :center },
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
        cell_styles[:text],           # Quota order number
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
        record[:quota_order_number],
        record[:chapter],
        record[:commodity_code],
        record[:commodity_code_description],
        record[:type_of_change],
        record[:change_detail],
        record[:date_of_effect].to_s,
        record[:ott_url] ? FastExcel::URL.new(record[:ott_url]) : nil,
        record[:api_url] ? FastExcel::URL.new(record[:api_url]) : nil,
      ]
    end

    def add_table_styling(sheet)
      return if @change_records.empty?

      sheet.add_table(4, 0, 4 + @change_records.length, excel_header_row.size - 1, style: 'TableStyleMedium2', columns: excel_header_row)
    end
  end
end
