module Reporting
  class Differences
    class Me16
      delegate :workbook,
               :regular_style,
               :bold_style,
               :each_chapter,
               to: :report

      WORKSHEET_NAME = 'ME16 candidates'.freeze

      HEADER_ROW = [
        'Commodity code',
        'Measure type',
      ].freeze

      TAB_COLOR = '000000'.freeze

      CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

      COLUMN_WIDTHS = [
        30, # Commodity code
        20, # Measure type
      ].freeze

      AUTOFILTER_CELL_RANGE = 'A5:B5'.freeze
      FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

      METRIC = 'ME16 candidates'.freeze
      SUBTEXT = 'This indicates that there are comm codes where a duty exists both with and without additional codes, which breaks ME16'.freeze

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
          sheet.add_row(['Back to overview', nil, nil, nil, nil], style: nil, hyperlink: { location: 'Overview!A1', target: :sheet })
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
          measures = {}

          PresentedMeasure.wrap(declarable.applicable_measures).each do |measure|
            measures[measure] ||= []
            measures[measure] << measure
          end

          measures.each do |measure, ms|
            next if measure.vat?

            additional_code_measures = ms.select(&:additional_code)
            no_additional_code_measures = ms.reject(&:additional_code)

            yield declarable, measure if additional_code_measures.any? && no_additional_code_measures.any?
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
          measure.measure_type_description,
        ]
      end

      class PresentedMeasure < WrapDelegator
        def hash
          [
            measure_type_id,
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
            ordernumber == other.ordernumber &&
            geographical_area_id == other.geographical_area_id
        end

        def additional_code
          "#{additional_code_type_id}#{additional_code_id}".presence || nil
        end

        def measure_type_description
          PresentedMeasure.measure_type_descriptions[measure_type_id]
        end

        def vat?
          measure_type_id.in? MeasureType::VAT_TYPES
        end

        def self.measure_type_descriptions
          @measure_type_descriptions ||= MeasureTypeDescription.all.index_by(&:measure_type_id)
        end
      end
    end
  end
end
