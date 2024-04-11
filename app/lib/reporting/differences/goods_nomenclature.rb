module Reporting
  class Differences
    class GoodsNomenclature
      delegate :workbook,
               :regular_style,
               :bold_style,
               :centered_style,
               :uk_goods_nomenclatures,
               :xi_goods_nomenclatures,
               :uk_goods_nomenclatures_for_comparison,
               :xi_goods_nomenclatures_for_comparison,
               to: :report

      WORKSHEET_NAME_EU = 'Commodities in EU, not in UK'.freeze
      WORKSHEET_NAME_UK = 'Commodities in UK, not in EU'.freeze

      HEADER_ROW = [
        'SID',
        'Commodity',
        'Product line suffix',
        'Start date',
        'End date',
        'Indentation',
        'End line',
        'Description',
        'New',
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
        12, # New
      ].freeze

      FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

      def initialize(source, target, report)
        @source = source
        @target = target
        @name = name
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

          rows.each do |row|
            report.increment_count(name)
            if row[8] # This is the PresentedGoodsNomenclature Object new_issue bool property
              report.increment_new_issue_count(name)
            end
            sheet.add_row(row, types: CELL_TYPES, style: regular_style)
            sheet.rows.last.tap do |last_row|
              last_row.cells[5].style = centered_style # Indentation
              last_row.cells[6].style = centered_style # End line
            end
          end

          sheet.column_widths(*COLUMN_WIDTHS)
        end
      end

      def name
        source == 'uk' ? WORKSHEET_NAME_UK : WORKSHEET_NAME_EU
      end

      private

      attr_reader :source, :target, :report

      def rows
        all_missing = source_goods_nomenclatures.keys - target_goods_nomenclatures.keys
        all_missing.map do |missing|
          build_row_for(missing)
        end
      end

      def build_row_for(missing)
        missing_goods_nomenclature = source_goods_nomenclatures[missing]
        # Check offset source report for the missing target record's ItemIDPlusPLS to show whether the issue existed n days ago. (For n see REPORTING_COMPARISON_DAYS_AGO)
        new_issue = !source_goods_nomenclatures_for_comparison.include?(missing_goods_nomenclature['ItemIDPlusPLS'])
        PresentedGoodsNomenclature.new(missing_goods_nomenclature, new_issue).to_row
      end

      def target_goods_nomenclatures
        @target_goods_nomenclatures ||= read_target.index_by do |goods_nomenclature|
          goods_nomenclature['ItemIDPlusPLS']
        end
      end

      def source_goods_nomenclatures
        @source_goods_nomenclatures ||= read_source.index_by do |goods_nomenclature|
          goods_nomenclature['ItemIDPlusPLS']
        end
      end

      def source_goods_nomenclatures_for_comparison
        @source_goods_nomenclatures_for_comparison ||= read_source_for_comparison.index_by do |goods_nomenclature|
          goods_nomenclature['ItemIDPlusPLS']
        end
      end

      def read_source
        public_send("#{source}_goods_nomenclatures")
      end

      def read_target
        public_send("#{target}_goods_nomenclatures")
      end

      def read_source_for_comparison
        public_send("#{source}_goods_nomenclatures_for_comparison")
      end

      def handle_csv(csv)
        CSV.parse(csv, headers: true).map(&:to_h)
      end
    end

    class PresentedGoodsNomenclature
      def initialize(goods_nomenclature, new_issue)
        @goods_nomenclature = goods_nomenclature
        @new_issue = new_issue
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
          new_issue,
        ]
      end

      private

      attr_reader :goods_nomenclature, :new_issue

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
  end
end
