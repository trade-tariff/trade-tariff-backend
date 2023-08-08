module Reporting
  class Differences
    class MfnMissing
      delegate :workbook,
               :regular_style,
               :bold_style,
               :each_chapter,
               to: :report

      HEADER_ROW = [
        'Commodity code',
        'Description',
      ].freeze

      TAB_COLOR = '00ff00'.freeze

      CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

      COLUMN_WIDTHS = [
        25, # Commodity code (PLS)
        80, # Description
      ].freeze

      AUTOFILTER_CELL_RANGE = 'A1:B1'.freeze
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
          end

          sheet.column_widths(*COLUMN_WIDTHS)
        end

        Rails.logger.debug("Query count: #{::SequelRails::Railties::LogSubscriber.count}")
      end

      private

      attr_reader :name, :report

      def rows
        acc = []

        each_declarable do |declarable|
          row = build_row_for(declarable)

          acc << row unless row.nil?
        end

        acc
      end

      def each_declarable
        each_chapter(eager: Differences::GOODS_NOMENCLATURE_OVERVIEW_MEASURE_EAGER) do |eager_chapter|
          eager_chapter.descendants.each do |chapter_descendant|
            next unless chapter_descendant.declarable?

            next if chapter_descendant.applicable_overview_measures.any? do |measure|
              measure.measure_type_id.in?(MeasureType::THIRD_COUNTRY)
            end

            yield chapter_descendant
          end
        end
      end

      def build_row_for(declarable)
        [
          declarable.goods_nomenclature_item_id,
          declarable.description,
        ]
      end
    end
  end
end
