module Reporting
  class Differences
    class Indentation
      delegate :get, to: TariffSynchronizer::FileService
      delegate :workbook, :bold_style, :centered_style, to: :report

      HEADER_ROW = [
        'Commodity code (PLS)',
        'UK indentation',
        'EU indentation',
      ].freeze

      TAB_COLOR = 'cc0000'.freeze

      CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

      COLUMN_WIDTHS = [
        20, # Commodity code (PLS)
        20, # UK indentation
        20, # EU indentation
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
            sheet.add_row(row, types: CELL_TYPES)
            sheet.rows.last.tap do |last_row|
              last_row.cells[1].style = centered_style # UK indentation
              last_row.cells[2].style = centered_style # EU indentation
            end
          end

          sheet.column_widths(*COLUMN_WIDTHS)
        end
      end

      private

      attr_reader :name, :report

      def rows
        matching_goods_nomenclature = uk_goods_nomenclatures & xi_goods_nomenclatures
        matching_goods_nomenclature.map do |matching|
          row = build_row_for(matching)
          next if row[1] == row[2]

          row
        end
      end

      def build_row_for(matching)
        matching_uk_goods_nomenclature = read_uk.find do |uk_goods_nomenclature|
          uk_goods_nomenclature['ItemIDPlusPLS'] == matching
        end

        matching_xi_goods_nomenclature = read_xi.find do |xi_goods_nomenclature|
          xi_goods_nomenclature['ItemIDPlusPLS'] == matching
        end

        [matching_uk_goods_nomenclature['ItemIDPlusPLS'], matching_uk_goods_nomenclature['Indentation'], matching_xi_goods_nomenclature['Indentation']]
      end

      def xi_goods_nomenclatures
        read_xi.pluck('ItemIDPlusPLS')
      end

      def uk_goods_nomenclatures
        read_uk.pluck('ItemIDPlusPLS')
      end

      def read_uk
        @read_uk ||= handle_csv(get("uk/goods_nomenclatures/#{Time.zone.today.iso8601}.csv"))
      end

      def read_xi
        @read_xi ||= handle_csv(get("xi/goods_nomenclatures/#{Time.zone.today.iso8601}.csv"))
      end

      def handle_csv(csv)
        CSV.parse(csv, headers: true).map(&:to_h)
      end
    end
  end
end
