module Reporting
  class Differences
    class MissingVatMeasure
      delegate :workbook,
               :regular_style,
               :bold_style,
               :each_chapter,
               to: :report

      FILTERED_MEASURE_TYPES = Set.new(%w[305]).freeze
      FILTERED_GEOGRAPHICAL_AREA_IDS = Set.new(%w[1011]).freeze

      HEADER_ROW = [
        'Commodity code',
        'Description',
      ].freeze

      TAB_COLOR = '666666'.freeze

      CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

      COLUMN_WIDTHS = [
        25, # Commodity code
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

          each_row do |row|
            sheet.add_row(row, types: CELL_TYPES, style: regular_style)
          end

          sheet.column_widths(*COLUMN_WIDTHS)
        end

        Rails.logger.debug("Query count: #{::SequelRails::Railties::LogSubscriber.count}")
      end

      private

      attr_reader :name, :report

      def each_row
        each_declarable do |declarable|
          row = build_row_for(declarable)

          yield row if row.present?
        end
      end

      def each_declarable
        each_chapter(eager: Differences::GOODS_NOMENCLATURE_OVERVIEW_MEASURE_EAGER) do |eager_chapter|
          eager_chapter.ns_descendants.each do |chapter_descendant|
            next unless chapter_descendant.ns_declarable?

            next if chapter_descendant.applicable_overview_measures.find { |measure|
              measure.measure_type_id.in?(FILTERED_MEASURE_TYPES) &&
                measure.geographical_area_id.in?(FILTERED_GEOGRAPHICAL_AREA_IDS)
            }.present?

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