module Reporting
  class Differences
    class CandidateSupplementaryUnit
      delegate :workbook,
               :regular_style,
               :bold_style,
               :centered_style,
               :each_chapter,
               to: :report

      WORKSHEET_NAME = 'Supp unit candidates'.freeze

      HEADER_ROW = [
        'Commodity code',
        'Unit(s)',
      ].freeze

      TAB_COLOR = '660066'.freeze

      CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

      COLUMN_WIDTHS = [
        20, # Commodity code
        20, # Unit(s)
      ].freeze

      AUTOFILTER_CELL_RANGE = 'A5:B5'.freeze
      FROZEN_VIEW_STARTING_CELL = 'A5'.freeze

      METRIC = 'Supplementary units that should be present'.freeze
      SUBTEXT = 'Excise etc. may require a supp unit that is not provided'.freeze

      def initialize(report)
        @report = report
      end

      def add_worksheet
        workbook.add_worksheet(name:) do |sheet|
          sheet.sheet_pr.tab_color = TAB_COLOR
          sheet.add_row([METRIC], style: bold_style)
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

          each_row do |row|
            report.increment_count(name)
            sheet.add_row(row, types: CELL_TYPES, style: regular_style)
            sheet.rows.last[1].style = centered_style
          end

          sheet.column_widths(*COLUMN_WIDTHS)
        end
      end

      def name
        WORKSHEET_NAME
      end

      private

      attr_reader :report

      def each_row
        each_chapter(eager: Differences::GOODS_NOMENCLATURE_MEASURE_WITH_UNIT_EAGER) do |eager_chapter|
          eager_chapter.descendants.each do |chapter_descendant|
            next unless chapter_descendant.declarable?

            supplementary_unit = chapter_descendant.applicable_measures.find(&:supplementary?)
            next if supplementary_unit.present?

            units = chapter_descendant
              .applicable_measures
              .flat_map(&:units)

            next if units.blank?

            units = units.map do |unit|
              "#{unit[:measurement_unit_code]}#{unit[:measurement_unit_qualifier]}"
            end

            yield [
              chapter_descendant.goods_nomenclature_item_id,
              units.uniq.join(', '),
            ]
          end
        end
      end
    end
  end
end
