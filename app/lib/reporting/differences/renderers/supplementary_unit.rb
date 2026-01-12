module Reporting
  class Differences
    module Renderers
      class SupplementaryUnit
        delegate :workbook,
                 :regular_style,
                 :bold_style,
                 :centered_style,
                 :uk_supplementary_unit_measures,
                 :xi_supplementary_unit_measures, to: :report

        WORKSHEET_NAME_EU = 'Supp units on EU not UK'.freeze
        WORKSHEET_NAME_UK = 'Supp units on UK not EU'.freeze

        HEADER_ROW = [
          'Commodity code',
          'Geographical area ID',
          'Measure type ID',
          'Measurement unit',
          'Measurement unit qualifier',
          'New?',
        ].freeze

        TAB_COLOR = '660066'.freeze

        COLUMN_WIDTHS = [
          20, # Commodity code
          20, # Geographical area ID
          20, # Measure type ID
          20, # Measurement unit
          30, # Measurement unit qualifier
          12, # New
        ].freeze

        METRIC = ERB.new('Supplementary units present on the <%= source_name %> tariff, but not on the <%= target_name %> tariff')
        SUBTEXT = 'May cause issues for Northern Ireland trade'.freeze

        def initialize(source, target, report)
          @source = source
          @target = target
          @name = name
          @report = report
        end

        attr_reader :source, :target, :report

        def add_worksheet(rows)
          workbook.add_worksheet(name) do |sheet|
            sheet.set_tab_color = TAB_COLOR
            sheet.append_row([rendered_metric], bold_style)
            sheet.merge_range(0, 1, 4, 1)
            sheet.append_row([SUBTEXT], regular_style)

            sheet.append_row([FastExcel::URL.new('internal:Overview!A1')])
            sheet.write_string(sheet.last_row_number, 0, 'Back to overview', nil)

            sheet.append_row([])
            sheet.append_row(HEADER_ROW, bold_style)
            sheet.autofilter(0, 4, 4, 4)
            sheet.freeze_panes(4, 0)

            (rows || []).each do |row|
              sheet.append_row(row, [regular_style, centered_style])
            end

            COLUMN_WIDTHS.each_with_index do |width, index|
              sheet.set_column_width(index, width)
            end
          end
        end

        def name
          source == 'uk' ? WORKSHEET_NAME_UK : WORKSHEET_NAME_EU
        end

        def rendered_metric
          METRIC.result(binding)
        end

        def source_name
          source == 'uk' ? 'UK' : 'EU'
        end

        def target_name
          target == 'uk' ? 'UK' : 'EU'
        end
      end
    end
  end
end
