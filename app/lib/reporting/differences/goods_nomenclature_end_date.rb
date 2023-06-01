module Reporting
  class Differences
    class GoodsNomenclatureEndDate
      delegate :workbook,
               :regular_style,
               :bold_style,
               :centered_style,
               :uk_goods_nomenclatures,
               :xi_goods_nomenclatures,
               to: :report

      HEADER_ROW = [
        'Commodity code (PLS)',
        'UK end date',
        'EU end date',
      ].freeze

      TAB_COLOR = 'cc0000'.freeze

      CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

      COLUMN_WIDTHS = [
        20, # Commodity code (PLS)
        20, # UK start date
        20, # EU start date
      ].freeze

      AUTOFILTER_CELL_RANGE = 'A1:C1'.freeze
      FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

      def initialize(name, report)
        @name = name
        @report = report
      end

      def add_worksheet
        workbook.add_worksheet(name:) do |sheet|
          sheet.sheet_pr.tab_color = TAB_COLOR
          sheet.add_row(HEADER_ROW, style: bold_style)
          sheet.auto_filter = AUTOFILTER_CELL_RANGE
          sheet.sheet_view.pane do |pane|
            pane.top_left_cell = FROZEN_VIEW_STARTING_CELL
            pane.state = :frozen
            pane.y_split = 1
          end

          rows.compact.each do |row|
            sheet.add_row(row, types: CELL_TYPES, style: regular_style)
            sheet.rows.last.tap do |last_row|
              last_row.cells[1].style = centered_style # UK start date
              last_row.cells[2].style = centered_style # EU start date
            end
          end

          sheet.column_widths(*COLUMN_WIDTHS)
        end
      end

      private

      attr_reader :name, :report

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

        uk_start_date = matching_uk_goods_nomenclature['End date']&.to_date&.strftime('%d/%m/%Y')
        eu_start_date = matching_xi_goods_nomenclature['End date']&.to_date&.strftime('%d/%m/%Y')

        return nil if uk_start_date == eu_start_date

        item_id, pls = matching_uk_goods_nomenclature['ItemIDPlusPLS'].split('_')

        [
          "#{item_id} (#{pls})",
          uk_start_date,
          eu_start_date,
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
    end
  end
end
