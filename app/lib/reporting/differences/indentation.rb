module Reporting
  class Differences
    class Indentation
      delegate :workbook,
               :regular_style,
               :bold_style,
               :centered_style,
               :uk_goods_nomenclatures,
               :xi_goods_nomenclatures,
               :uk_goods_nomenclatures_for_comparison,
               :xi_goods_nomenclatures_for_comparison,
               to: :report

      WORKSHEET_NAME = 'Indentation differences'.freeze

      HEADER_ROW = [
        'Commodity code (PLS)',
        'UK indentation',
        'EU indentation',
        'New',
      ].freeze

      TAB_COLOR = 'cc0000'.freeze

      CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

      COLUMN_WIDTHS = [
        20, # Commodity code (PLS)
        20, # UK indentation
        20, # EU indentation
        20, # New
      ].freeze

      FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

      def initialize(report)
        @report = report
      end

      def add_worksheet
        workbook.add_worksheet(name:) do |sheet|
          sheet.sheet_pr.tab_color = TAB_COLOR
          sheet.add_row(HEADER_ROW, style: bold_style)
          sheet.sheet_view.pane do |pane|
            pane.top_left_cell = FROZEN_VIEW_STARTING_CELL
            pane.state = :frozen
            pane.y_split = 1
          end

          rows.compact.each do |row|
            report.increment_count(name)
            if row.last # last value in a row array is new_issue
              report.increment_new_issue_count(name)
            end
            sheet.add_row(row, types: CELL_TYPES, style: regular_style)
            sheet.rows.last.tap do |last_row|
              last_row.cells[1].style = centered_style # UK indentation
              last_row.cells[2].style = centered_style # EU indentation
            end
          end

          sheet.column_widths(*COLUMN_WIDTHS)
        end
      end

      def name
        WORKSHEET_NAME
      end

      private

      attr_reader :report

      def rows
        matching_goods_nomenclature = uk_goods_nomenclature_ids.keys & xi_goods_nomenclature_ids.keys

        matching_goods_nomenclature.each_with_object([]) do |matching, acc|
          row = build_row_for(matching)
          acc << row unless row.nil?
        end
      end

      def build_row_for(matching)
        matching_uk_goods_nomenclature = uk_goods_nomenclature_ids[matching]
        matching_xi_goods_nomenclature = xi_goods_nomenclature_ids[matching]

        return nil if matching_uk_goods_nomenclature['Indentation'] == matching_xi_goods_nomenclature['Indentation']

        item_id, pls = matching_uk_goods_nomenclature['ItemIDPlusPLS'].split('_')

        matching_uk_goods_nomenclature_for_comparison = uk_goods_nomenclature_ids_for_comparison[matching]
        matching_xi_goods_nomenclature_for_comparison = xi_goods_nomenclature_ids_for_comparison[matching]

        new_issue = if matching_uk_goods_nomenclature_for_comparison.nil? || matching_xi_goods_nomenclature_for_comparison.nil?
                      true
                    else
                      matching_uk_goods_nomenclature_for_comparison['Indentation'] == matching_xi_goods_nomenclature_for_comparison['Indentation']
                    end

        [
          "#{item_id} (#{pls})",
          matching_uk_goods_nomenclature['Indentation'],
          matching_xi_goods_nomenclature['Indentation'],
          new_issue,
        ]
      end

      def uk_goods_nomenclature_ids
        @uk_goods_nomenclature_ids ||= uk_goods_nomenclatures.index_by do |goods_nomenclature|
          goods_nomenclature['ItemIDPlusPLS']
        end
      end

      def xi_goods_nomenclature_ids
        @xi_goods_nomenclature_ids ||= xi_goods_nomenclatures.index_by do |goods_nomenclature|
          goods_nomenclature['ItemIDPlusPLS']
        end
      end

      def uk_goods_nomenclature_ids_for_comparison
        @uk_goods_nomenclature_ids_for_comparison ||= uk_goods_nomenclatures_for_comparison.index_by do |goods_nomenclature|
          goods_nomenclature['ItemIDPlusPLS']
        end
      end

      def xi_goods_nomenclature_ids_for_comparison
        @xi_goods_nomenclature_ids_for_comparison ||= xi_goods_nomenclatures_for_comparison.index_by do |goods_nomenclature|
          goods_nomenclature['ItemIDPlusPLS']
        end
      end
    end
  end
end
