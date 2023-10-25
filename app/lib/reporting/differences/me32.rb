module Reporting
  class Differences
    class Me32
      delegate :workbook,
               :regular_style,
               :bold_style,
               :each_chapter,
               to: :report

      WORKSHEET_NAME = 'ME32 candidates'.freeze

      HEADER_ROW = [
        'Commodity code',
        'Measure type',
        'Additional code',
        'Order number',
        'Geography',
      ].freeze

      TAB_COLOR = '00ff00'.freeze

      CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

      COLUMN_WIDTHS = [
        30, # Commodity code
        20, # Measure type
        20, # Additional code
        20, # Order number
        20, # Geography
      ].freeze

      AUTOFILTER_CELL_RANGE = 'A5:E5'.freeze
      FROZEN_VIEW_STARTING_CELL = 'A5'.freeze

      METRIC = 'ME32 candidates'.freeze
      SUBTEXT = 'There may be no overlap in time with other measure occurrences with a goods code in the same nomenclature hierarchy which references the same measure type, geo area, order number and additional code.'.freeze

      def initialize(report)
        @report = report
      end

      def add_worksheet
        workbook.add_worksheet(name:) do |sheet|
          sheet.sheet_pr.tab_color = TAB_COLOR
          sheet.add_row([METRIC], style: bold_style)
          subtext_row = sheet.add_row([SUBTEXT], style: regular_style)
          subtext_row.height = 30
          sheet.merge_cells('A2:E2')
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

          rows.compact.each do |row|
            report.increment_count(name)
            sheet.add_row(row, types: CELL_TYPES, style: regular_style)
          end

          sheet.column_widths(*COLUMN_WIDTHS)
        end

        Rails.logger.debug("Query count: #{::SequelRails::Railties::LogSubscriber.count}")
      end

      def name
        WORKSHEET_NAME
      end

      private

      attr_reader :report

      def rows
        acc = []

        each_declarable_and_measure do |declarable, measure|
          row = build_row_for(declarable, measure)

          acc << row unless row.nil?
        end

        acc
      end

      def each_declarable_and_measure
        each_declarable do |declarable|
          counts = Hash.new(0)

          PresentedMeasure.wrap(declarable.applicable_measures).each do |measure|
            counts[measure] += 1
          end

          counts.each do |measure, count|
            next if count == 1

            yield declarable, measure
          end
        end
      end

      def each_declarable
        each_chapter(eager: Differences::GOODS_NOMENCLATURE_MEASURE_EAGER) do |eager_chapter|
          eager_chapter.descendants.each do |chapter_descendant|
            next unless chapter_descendant.declarable?

            yield chapter_descendant
          end
        end
      end

      def build_row_for(declarable, measure)
        [
          declarable.goods_nomenclature_item_id,
          measure.measure_type_id,
          measure.additional_code,
          measure.ordernumber,
          measure.geographical_area_id,
        ]
      end

      class PresentedMeasure < WrapDelegator
        def hash
          [
            measure_type_id,
            additional_code,
            ordernumber,
            geographical_area_id,
          ].hash
        end

        # Used as a secondary check (primary being the #hash method)
        # when comparing measures in an accumulating hash.
        #
        # This enables us to pick out duplicate measures based on a custom
        # definition of equality.
        def eql?(other)
          measure_type_id == other.measure_type_id &&
            additional_code == other.additional_code &&
            ordernumber == other.ordernumber &&
            geographical_area_id == other.geographical_area_id
        end

        def additional_code
          "#{additional_code_type_id}#{additional_code_id}".presence || nil
        end
      end
    end
  end
end
