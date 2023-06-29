module Reporting
  class BulkSearch
    extend Reporting::Reportable

    class << self
      def generate(data)
        package = new(data).generate
        package.serialize('bulk_search.xlsx') if Rails.env.development?

        if Rails.env.production?
          object.put(
            body: package.to_stream.read,
            content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          )
        end

        Rails.logger.debug("Query count: #{::SequelRails::Railties::LogSubscriber.count}")
      end

      def object_key
        "#{service}/reporting/#{year}/#{month}/#{day}/bulk_search_#{now.strftime('%Y_%m_%d')}.xlsx"
      end
    end

    def initialize(data)
      @package = Axlsx::Package.new
      @package.use_shared_strings = true
      @workbook = package.workbook
      @bold_style = workbook.styles.add_style(
        b: true,
        font_name: 'Calibri',
        sz: 11,
      )
      @regular_style = workbook.styles.add_style(
        alignment: {
          wrap_text: true,
        },
        font_name: 'Calibri',
        sz: 11,
      )
      @centered_style = workbook.styles.add_style(
        alignment: {
          horizontal: :center,
          wrap_text: true,
        },
        font_name: 'Calibri',
        sz: 11,
      )
      @autofilter_cell_range = 'A1:E1'

      @column_widths = [
        50,
        10,
        10,
        20,
        50,
      ]

      @styles = [
        @regular_style,
        @center_style,
        @center_style,
        @center_style,
        @regular_style,
      ]

      @header_row = [
        'Input Description',
        '6 digit answer',
        'Score',
        'Was this correct?',
        'Notes',
      ]

      @data = data
    end

    def generate
      add_overview_worksheet
      add_matched_worksheet
      add_missing_worksheet
      add_no_result_worksheet

      package
    end

    private

    attr_reader :package,
                :workbook,
                :bold_style,
                :regular_style,
                :centered_style,
                :data,
                :autofilter_cell_range,
                :column_widths,
                :styles,
                :header_row

    def add_overview_worksheet
      headers = [
        'Elapsed Time',
        'Number of Results',
        'Number of Matches',
        'Number of Misses',
        'Number of No Result',
        'Percentage of Matches',
      ]
      overview_row = [
        data[:elapsed_time],
        data[:number_of_results],
        data[:number_of_matches],
        data[:number_of_misses],
        data[:number_of_no_result],
        data[:percentage_of_matches],
      ]

      package.workbook.add_worksheet(name: 'Overview') do |sheet|
        sheet.sheet_pr.tab_color = '000000'
        sheet.add_row headers, style: bold_style
        sheet.add_row overview_row, style: regular_style
        sheet.add_chart(Axlsx::Bar3DChart, start_at: 'A6', end_at: 'F20', bar_dir: :col) do |chart|
          chart.add_series data: sheet['C2:E2'], labels: sheet['C1:E1'], title: ''
          chart.catAxis.title = 'Result Type'
          chart.valAxis.title = 'Result Count'
        end
      end
    end

    def add_matched_worksheet
      package.workbook.add_worksheet(name: 'Matches') do |sheet|
        sheet.sheet_pr.tab_color = '00FF00'
        sheet.add_row(header_row, style: bold_style)
        sheet.auto_filter = autofilter_cell_range
        sheet.sheet_view.pane do |pane|
          pane.top_left_cell = 'A2'
          pane.state = :frozen
          pane.y_split = 1
        end
        data[:matches].each do |row_data|
          sheet.add_row build_row_for(row_data), styles:
        end
        sheet.add_data_validation('D2:D100', {
          type: :list,
          formula1: '"This is incorrect, This is correct, This could be correct"',
          hideDropDown: false,
          showErrorMessage: true,
          errorTitle: 'Invalid input',
          errorMessage: 'Please select either "This is incorrect", "This is correct" or "This could be correct"',
        })
        sheet.column_widths(*column_widths)
      end
    end

    def add_missing_worksheet
      package.workbook.add_worksheet(name: 'No Matches') do |sheet|
        sheet.sheet_pr.tab_color = 'FFFF00'
        sheet.add_row(header_row, style: bold_style)
        sheet.auto_filter = autofilter_cell_range
        sheet.sheet_view.pane do |pane|
          pane.top_left_cell = 'A2'
          pane.state = :frozen
          pane.y_split = 1
        end
        data[:misses].each do |row_data|
          sheet.add_row build_row_for(row_data), styles:
        end
        sheet.add_data_validation('D2:D100', {
          type: :list,
          formula1: '"This is incorrect, This is correct, This could be correct"',
          hideDropDown: false,
          showErrorMessage: true,
          errorTitle: 'Invalid input',
          errorMessage: 'Please select either "This is incorrect", "This is correct" or "This could be correct"',
        })
        sheet.column_widths(*column_widths)
      end
    end

    def add_no_result_worksheet
      package.workbook.add_worksheet(name: 'No Results') do |sheet|
        sheet.sheet_pr.tab_color = 'FF0000'
        sheet.add_row(header_row, style: bold_style)
        sheet.auto_filter = autofilter_cell_range
        sheet.sheet_view.pane do |pane|
          pane.top_left_cell = 'A2'
          pane.state = :frozen
          pane.y_split = 1
        end
        data[:no_result].each do |row_data|
          sheet.add_row build_row_for(row_data), styles:
        end
        sheet.add_data_validation('D2:D100', {
          type: :list,
          formula1: '"This is incorrect, This is correct, This could be correct"',
          hideDropDown: false,
          showErrorMessage: true,
          errorTitle: 'Invalid input',
          errorMessage: 'Please select either "This is incorrect", "This is correct" or "This could be correct"',
        })
        sheet.column_widths(*column_widths)
      end
    end

    def build_row_for(row_data)
      [
        row_data[:input_description],
        row_data[:short_code],
        row_data[:score],
      ]
    end
  end
end
