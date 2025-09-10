class DeltaReportService
  class ExcelGenerator
    def self.call(change_records, dates)
      return if change_records.empty?

      new(change_records, dates).call
    end

    attr_accessor :change_records, :dates, :workbook

    def initialize(change_records, dates)
      @change_records = change_records
      @dates = dates
    end

    def call
      package = Axlsx::Package.new
      package.use_shared_strings = true
      @workbook = package.workbook

      styles = excel_cell_styles

      workbook.add_worksheet(name: 'Delta Report') do |sheet|
        # Add pre-header row
        pre_header_styles = [styles[:pre_header]] * 8 + [styles[:pre_header_detail]] * 4
        sheet.add_row(['Change Location', '', '', '', '', '', '', '', 'Change Detail', '', '', ''], style: pre_header_styles)
        sheet.rows[0].height = 25
        sheet.merge_cells('A1:H1')
        sheet.merge_cells('I1:L1')

        # Add header row
        header_styles = [styles[:header]] * 8 + [styles[:header_detail]] * 4
        sheet.add_row(excel_header_row, style: header_styles)

        # Configure sheet view
        sheet.auto_filter = excel_autofilter_range
        sheet.sheet_view.pane do |pane|
          pane.top_left_cell = 'A3'
          pane.state = :frozen
          pane.y_split = 2
        end

        @change_records.each do |date|
          date.each do |record|
            sheet.add_row(
              build_excel_row(record),
              types: excel_cell_types,
              style: build_row_styles(styles, record),
            )
          end
        end

        sheet.column_widths(*excel_column_widths)
      end

      package.serialize("delta_report_#{dates}.xlsx") if Rails.env.development?

      package
    end

    def excel_header_row
      [
        'Chapter',
        'Commodity Code',
        'Commodity description',
        'Import/Export',
        'Measure Type',
        'Measure Geo area',
        'Additional code',
        'Type of change',
        'Updated code/data',
        'Date of effect',
        'Operation Date',
      ]
    end

    def excel_autofilter_range
      "A2:#{('A'.ord + excel_header_row.size - 1).chr}2"
    end

    def excel_column_widths
      [
        15,  # Chapter
        20,  # Commodity Code
        50,  # Commodity Description
        20,  # Import/Export
        30,  # Measure Type
        30,  # Geo Area
        30,  # Additional Code
        30,  # Type of Change
        30,  # Updated code/data
        22,  # Date of effect
        20,  # Operation Date
      ]
    end

    def excel_cell_types
      [
        :string,  # Chapter (for number formatting)
        :string,  # Commodity Code (for number formatting)
        :string,  # Commodity Description
        :string,  # Import/Export
        :string,  # Measure Type
        :string,  # Geo Area
        :string,  # Additional Code
        :string,  # Type of Change
        :string,  # Updated code/data
        :string,  # Date of effect
        :string,  # Operation Date
      ]
    end

    def excel_cell_styles
      {
        pre_header: workbook.styles.add_style(
          b: true,
          bg_color: 'A6A6A6',
          fg_color: '000000',
          border: { style: :thin, color: '000000' },
          alignment: { horizontal: :left, vertical: :center, wrap_text: true },
          sz: 16,
        ),
        pre_header_detail: workbook.styles.add_style(
          b: true,
          bg_color: 'F1A983',
          fg_color: '000000',
          border: { style: :thin, color: '000000' },
          alignment: { horizontal: :left, vertical: :center, wrap_text: true },
          sz: 16,
        ),
        header: workbook.styles.add_style(
          b: true,
          bg_color: 'D9D9D9',
          fg_color: '000000',
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :center, vertical: :center, wrap_text: true },
        ),
        header_detail: workbook.styles.add_style(
          b: true,
          bg_color: 'FBE2D5',
          fg_color: '000000',
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :center, vertical: :center, wrap_text: true },
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
        change_added: workbook.styles.add_style(
          bg_color: 'D5F4E6',
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :left, vertical: :center, wrap_text: true },
        ),
        change_removed: workbook.styles.add_style(
          bg_color: 'FADAD7',
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :left, vertical: :center, wrap_text: true },
        ),
        change_updated: workbook.styles.add_style(
          bg_color: 'FFF2CC',
          border: { style: :thin, color: 'D3D3D3' },
          alignment: { horizontal: :left, vertical: :center, wrap_text: true },
        ),
      }
    end

    def build_row_styles(styles, record)
      # Determine the change type style based on the type of change
      change_style = case record[:type_of_change]
                     when /added/i
                       styles[:change_added]
                     when /removed/i
                       styles[:change_removed]
                     else
                       styles[:change_updated]
                     end

      [
        styles[:chapter],        # Chapter
        styles[:commodity_code], # Commodity Code
        styles[:text],           # Commodity Description
        styles[:text],           # Import/Export
        styles[:text],           # Measure Type
        styles[:text],           # Geo Area
        styles[:text],           # Additional Code
        styles[:text],           # Type of Change
        change_style,            # Updated code/data (conditional styling)
        styles[:date],           # Date of effect
        styles[:date],           # Operation Date
      ]
    end

    def build_excel_row(record)
      [
        record[:chapter],
        record[:commodity_code],
        record[:commodity_code_description],
        record[:import_export],
        record[:measure_type],
        record[:geo_area],
        record[:additional_code],
        record[:type_of_change],
        record[:change],
        record[:date_of_effect]&.strftime('%Y-%m-%d'),
        record[:operation_date],
      ]
    end
  end
end
