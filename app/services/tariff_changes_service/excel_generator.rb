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
      package = Axlsx::Package.new
      package.use_shared_strings = true
      @workbook = package.workbook

      workbook.add_worksheet(name: 'Commodity watch list') do |sheet|
        setup_sheet_formatting(sheet)
        add_headers(sheet)
        stream_data_rows(sheet)
        add_table_styling(sheet)
        set_column_widths(sheet)
      end

      package
    end

    private

    def setup_sheet_formatting(sheet)
      sheet.sheet_format_pr.default_row_height = 40.0
      sheet.sheet_format_pr.custom_height = false
    end

    def add_headers(sheet)
      # Title row
      sheet.add_row(['Changes to your commodity watch list'], style: workbook.styles.add_style(b: true, sz: 24))
      sheet.rows[0].height = 40

      # Subtitle row
      sheet.add_row(["Published #{date}"], style: workbook.styles.add_style(b: false, sz: 16))
      sheet.rows[1].height = 25

      # Empty row
      sheet.add_row([''])
      sheet.rows[2].height = 20

      # Pre-header row
      pre_header_styles = [cell_styles[:pre_header]] * 12
      sheet.add_row(['Is this change relevant to your business (useful filters)', '', '', '', 'Impacted Commodity details', '', '', 'Change details', '', '', 'Useful Links', ''], style: pre_header_styles)
      sheet.rows[3].height = 40

      # Merge pre-header cells
      sheet.merge_cells('A4:D4')
      sheet.merge_cells('E4:G4')
      sheet.merge_cells('H4:J4')
      sheet.merge_cells('K4:L4')

      # Header row
      header_styles = [cell_styles[:header]] * 12
      sheet.add_row(excel_header_row, style: header_styles)
      sheet.rows[4].height = 40
    end

    def stream_data_rows(sheet)
      @change_records.each_slice(100) do |batch|
        batch.each do |record|
          row = sheet.add_row(
            build_excel_row(record),
            types: [:string] * 12,
            style: build_row_styles,
          )

          add_hyperlinks(sheet, row, record)
        end
      end
    end

    def set_column_widths(sheet)
      sheet.column_widths(*excel_column_widths)
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
        pre_header: workbook.styles.add_style(
          b: true,
          bg_color: '215c98',
          fg_color: 'ffffff',
          border: { style: :thin, color: '000000' },
          alignment: { horizontal: :left, vertical: :center, wrap_text: true },
          sz: 16,
        ),
        header: workbook.styles.add_style(
          b: true,
          alignment: { horizontal: :left, vertical: :center, wrap_text: true },
        ),
        date: workbook.styles.add_style(
          num_fmt: 14,
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :center, vertical: :center },
        ),
        commodity_code: workbook.styles.add_style(
          format_code: '0000000000',
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :center, vertical: :center },
        ),
        chapter: workbook.styles.add_style(
          format_code: '00',
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :center, vertical: :center },
        ),
        text: workbook.styles.add_style(
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :left, vertical: :center, wrap_text: true },
        ),
        center_text: workbook.styles.add_style(
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :center, vertical: :center },
        ),
        hyperlink: workbook.styles.add_style(
          fg_color: '0563C1',
          u: true,
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :left, vertical: :center, wrap_text: true },
        ),
        bold_text: workbook.styles.add_style(
          b: true,
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :left, vertical: :center, wrap_text: true },
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
      ott_cell = row.cells[10]
      api_cell = row.cells[11]

      sheet.add_hyperlink(location: record[:ott_url], ref: ott_cell) if record[:ott_url]
      sheet.add_hyperlink(location: record[:api_url], ref: api_cell) if record[:api_url]
    end

    def add_table_styling(sheet)
      return if @change_records.empty?

      header_row = 5
      last_data_row = header_row + @change_records.length
      last_col_letter = ('A'.ord + excel_header_row.size - 1).chr
      table_range = "A#{header_row}:#{last_col_letter}#{last_data_row}"

      sheet.add_table table_range, style_info: {
        name: 'TableStyleMedium2',
        show_first_column: false,
        show_last_column: false,
        show_row_stripes: true,
        show_column_stripes: false,
      }
    end
  end
end
