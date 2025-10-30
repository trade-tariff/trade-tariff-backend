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

      workbook.add_worksheet(name: 'Commodity Watchlist') do |sheet|
        setup_sheet_formatting(sheet)
        add_headers(sheet)
        stream_data_rows(sheet)
        configure_sheet_view(sheet)
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
      sheet.add_row(['Changes to your Commodity Watchlist'], style: workbook.styles.add_style(b: true, sz: 24))
      sheet.rows[0].height = 40

      # Subtitle row
      sheet.add_row(["Published #{date}"], style: workbook.styles.add_style(b: false, sz: 16))
      sheet.rows[1].height = 25

      # Empty row
      sheet.add_row([''])
      sheet.rows[2].height = 20

      # Pre-header row
      pre_header_styles = [cell_styles[:pre_header]] * 11
      sheet.add_row(['Is this change relevant to your business (useful filters)', '', '', 'Impacted Commodity details', '', '', 'Change details', '', '', 'Useful Links', ''], style: pre_header_styles)
      sheet.rows[3].height = 40

      # Merge pre-header cells
      sheet.merge_cells('A4:C4')
      sheet.merge_cells('D4:F4')
      sheet.merge_cells('G4:I4')
      sheet.merge_cells('J4:K4')

      # Header row
      header_styles = [cell_styles[:header]] * 11
      sheet.add_row(excel_header_row, style: header_styles)
      sheet.rows[4].height = 60
    end

    def stream_data_rows(sheet)
      index = 0

      @change_records.each_slice(100) do |batch|
        batch.each do |record|
          sheet.add_row(
            build_excel_row(record),
            types: [:string] * 11,
            style: build_row_styles(is_even_row: index.even?),
          )
          index += 1
        end
      end
    end

    def configure_sheet_view(sheet)
      sheet.auto_filter = excel_autofilter_range
      sheet.sheet_view.pane do |pane|
        pane.top_left_cell = 'A6'
        pane.state = :frozen
        pane.y_split = 5
      end
    end

    def set_column_widths(sheet)
      sheet.column_widths(*excel_column_widths)
    end

    def excel_header_row
      [
        "Import/Export\n(if applicable)",
        "Impacted Geographical area\n(if applicable)",
        "Impacted Measure\n(if applicable)",
        'Chapter',
        'Commodity Code',
        'Commodity Code description',
        'Change Type',
        'New / Impacted Detail',
        'Change Date of Effect',
        'View OTT for Change Date of Effect',
        'API call for the changed Commodity',
      ]
    end

    def excel_autofilter_range
      "A5:#{('A'.ord + excel_header_row.size - 3).chr}5"
    end

    def excel_column_widths
      [
        20,  # Import/Export
        30,  # Geo Area
        30,  # Measure
        15,  # Chapter
        20,  # Commodity Code
        50,  # Commodity Description
        30,  # Change type
        30,  # Updated code/data
        22,  # Date of effect
        80,  # OTT Link
        60,  # API Link
      ]
    end

    def cell_styles(bg_colour = nil)
      @cell_styles ||= {}
      @cell_styles[bg_colour] ||= {
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
          bg_color: '0e769e',
          fg_color: 'ffffff',
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :left, vertical: :center, wrap_text: true },
        ),
        date: workbook.styles.add_style(
          bg_color: bg_colour,
          num_fmt: 14,
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :center, vertical: :center },
        ),
        commodity_code: workbook.styles.add_style(
          bg_color: bg_colour,
          format_code: '0000000000',
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :center, vertical: :center },
        ),
        chapter: workbook.styles.add_style(
          bg_color: bg_colour,
          format_code: '00',
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :center, vertical: :center },
        ),
        text: workbook.styles.add_style(
          bg_color: bg_colour,
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :left, vertical: :center, wrap_text: true },
        ),
        center_text: workbook.styles.add_style(
          bg_color: bg_colour,
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :center, vertical: :center },
        ),
        bold_text: workbook.styles.add_style(
          bg_color: bg_colour,
          b: true,
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :left, vertical: :center, wrap_text: true },
        ),
      }
    end

    def build_row_styles(is_even_row: true)
      # Background color for alternating rows
      bg_color = is_even_row ? nil : 'd9d9d9'

      [
        cell_styles(bg_color)[:text],           # Import/Export
        cell_styles(bg_color)[:text],           # Geo Area
        cell_styles(bg_color)[:text],           # Measure Type
        cell_styles(bg_color)[:chapter],        # Chapter
        cell_styles(bg_color)[:commodity_code], # Commodity Code
        cell_styles(bg_color)[:text],           # Commodity Description
        cell_styles(bg_color)[:bold_text],      # Type of Change
        cell_styles(bg_color)[:text],           # Updated code/data
        cell_styles(bg_color)[:date],           # Date of effect
        cell_styles(bg_color)[:text],           # OTT Link
        cell_styles(bg_color)[:text],           # API Link
      ]
    end

    def build_excel_row(record)
      [
        record[:import_export],
        record[:geo_area],
        record[:measure_type],
        record[:chapter],
        record[:commodity_code],
        record[:commodity_code_description],
        record[:type_of_change],
        record[:change],
        record[:date_of_effect],
        record[:ott_url],
        record[:api_url],
      ]
    end
  end
end
