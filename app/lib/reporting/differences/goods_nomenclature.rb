module Reporting
  class Differences
    class PresentedGoodsNomenclature
      def initialize(goods_nomenclature)
        @goods_nomenclature = goods_nomenclature
      end

      def to_row
        [
          sid,
          commodity_code,
          product_line_suffix,
          start_date,
          end_date,
          indentation,
          end_line,
          description,
        ]
      end

      private

      attr_reader :goods_nomenclature

      def sid
        goods_nomenclature['SID']
      end

      def commodity_code
        goods_nomenclature['Commodity code']
      end

      def product_line_suffix
        goods_nomenclature['Product line suffix']
      end

      def start_date
        goods_nomenclature['Start date']&.to_date&.strftime('%d/%m/%Y')
      end

      def end_date
        goods_nomenclature['End date']&.to_date&.strftime('%d/%m/%Y')
      end

      def indentation
        goods_nomenclature['Indentation']
      end

      def end_line
        goods_nomenclature['End line'] == 'true' ? '1' : '0'
      end

      def description
        goods_nomenclature['Description']
      end
    end

    class GoodsNomenclature
      delegate :workbook,
               :bold_style,
               :centered_style,
               :uk_goods_nomenclatures,
               :xi_goods_nomenclatures,
               to: :report

      HEADER_ROW = [
        'SID',
        'Commodity',
        'Product line suffix',
        'Start date',
        'End date',
        'Indentation',
        'End line',
        'Description',
      ].freeze

      TAB_COLOR = 'cc0000'.freeze

      CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

      COLUMN_WIDTHS = [
        12, # SID
        12, # Commodity
        12, # Product line suffix
        12, # Start date
        12, # End date
        12, # Indentation
        12, # End line
        80, # Description
      ].freeze

      AUTOFILTER_CELL_RANGE = 'A1:H1'.freeze
      FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

      def initialize(source, target, name, report)
        @source = source
        @target = target
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

          rows.each do |row|
            sheet.add_row(row, types: CELL_TYPES)
            sheet.rows.last.tap do |last_row|
              last_row.cells[5].style = centered_style # Indentation
              last_row.cells[6].style = centered_style # End line
            end
          end

          sheet.column_widths(*COLUMN_WIDTHS)
        end
      end

      private

      attr_reader :source, :target, :name, :report

      def rows
        all_missing = source_goods_nomenclatures.keys - target_goods_nomenclatures.keys
        all_missing.map do |missing|
          build_row_for(missing)
        end
      end

      def build_row_for(missing)
        missing_goods_nomenclature = source_goods_nomenclatures[missing]

        PresentedGoodsNomenclature.new(missing_goods_nomenclature).to_row
      end

      def target_goods_nomenclatures
        @target_goods_nomenclatures ||= read_target.each_with_object({}) do |goods_nomenclature, acc|
          acc[goods_nomenclature['ItemIDPlusPLS']] = goods_nomenclature
        end
      end

      def source_goods_nomenclatures
        @source_goods_nomenclatures ||= read_source.each_with_object({}) do |goods_nomenclature, acc|
          acc[goods_nomenclature['ItemIDPlusPLS']] = goods_nomenclature
        end
      end

      def read_source
        public_send("#{source}_goods_nomenclatures")
      end

      def read_target
        public_send("#{target}_goods_nomenclatures")
      end

      def handle_csv(csv)
        CSV.parse(csv, headers: true).map(&:to_h)
      end
    end
  end
end
