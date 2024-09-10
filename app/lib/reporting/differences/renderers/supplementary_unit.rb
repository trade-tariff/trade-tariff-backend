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

        CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

        COLUMN_WIDTHS = [
          20, # Commodity code
          20, # Geographical area ID
          20, # Measure type ID
          20, # Measurement unit
          30, # Measurement unit qualifier
          12, # New
        ].freeze

        AUTOFILTER_CELL_RANGE = 'A5:E5'.freeze
        FROZEN_VIEW_STARTING_CELL = 'A5'.freeze

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
          workbook.add_worksheet(name:) do |sheet|
            sheet.sheet_pr.tab_color = TAB_COLOR
            sheet.add_row([rendered_metric], style: bold_style)
            sheet.merge_cells('A2:E2')
            sheet.add_row([SUBTEXT], style: regular_style)
            sheet.add_row(['Back to overview'])
            sheet.add_hyperlink(
              location: "'Overview'!A1",
              target: :sheet,
              ref: sheet.rows.last[0].r,
            )
            sheet.add_row([])
            sheet.add_row(HEADER_ROW, style: bold_style)
            sheet.auto_filter = AUTOFILTER_CELL_RANGE
            sheet.sheet_view.pane do |pane|
              pane.top_left_cell = FROZEN_VIEW_STARTING_CELL
              pane.state = :frozen
              pane.y_split = 1
            end

            (rows || []).each do |row|
              sheet.add_row(row, types: CELL_TYPES, style: centered_style)
              sheet.rows.last.tap do |last_row|
                last_row.cells[0].style = regular_style # Commodity code
              end
            end

            sheet.column_widths(*COLUMN_WIDTHS)
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
