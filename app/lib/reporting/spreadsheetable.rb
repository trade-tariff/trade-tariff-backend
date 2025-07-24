module Reporting
  module Spreadsheetable
    extend ActiveSupport::Concern

    def create_spreadsheet(&_block)
      package = Axlsx::Package.new
      package.use_shared_strings = true
      workbook = package.workbook
      bold_style = workbook.styles.add_style(b: true)

      workbook.add_worksheet(name: Time.zone.today.iso8601) do |sheet|
        sheet.add_row(self::HEADER_ROW, style: bold_style)
        sheet.auto_filter = self::AUTOFILTER_CELL_RANGE
        sheet.sheet_view.pane do |pane|
          pane.top_left_cell = self::FROZEN_VIEW_STARTING_CELL
          pane.state = :frozen
          pane.y_split = 1
        end

        yield(sheet) if block_given?

        sheet.column_widths(*self::COLUMN_WIDTHS) # Set this after the rows have been added, otherwise it won't work
      end

      package
    end

    def save_document(object, object_key, package)
      package.serialize(File.basename(object_key)) if Rails.env.development?

      if Rails.env.production?
        object.put(
          body: package.to_stream.read,
          content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        )
      end
    end
  end
end
