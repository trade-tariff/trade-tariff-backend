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

        TAB_COLOR = 0x660066

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
          worksheet = workbook.add_worksheet(name)
          worksheet.set_tab_color(TAB_COLOR)
          worksheet.append_row([rendered_metric], bold_style)
          worksheet.append_row([])
          worksheet.merge_range(1, 0, 1, 4, SUBTEXT, regular_style)

          worksheet.append_row([])
          worksheet.write_url_opt(
            worksheet.last_row_number,
            0,
            "internal:'Overview'!A1",
            nil,
            'Back to overview',
            nil,
          )
          worksheet.append_row([])

          worksheet.append_row(HEADER_ROW, bold_style)
          worksheet.autofilter(4, 0, 4, 4)
          worksheet.freeze_panes(5, 0)

          (rows || []).each do |row|
            worksheet.append_row(row, [regular_style, centered_style])
          end

          COLUMN_WIDTHS.each_with_index do |width, index|
            worksheet.set_column_width(index, width)
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
