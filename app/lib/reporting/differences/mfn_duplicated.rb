module Reporting
  class Differences
    class MfnDuplicated
      delegate :workbook,
               :regular_style,
               :bold_style,
               :each_chapter,
               to: :report

      WORKSHEET_NAME = 'Duplicate MFNs'.freeze

      HEADER_ROW = [
        'Commodity code',
        'Headline',
        'MFN 1 - SID',
        'MFN 1 - Add code',
        'MFN 1 - Duty',
        'MFN 1 - Measure type',
        'MFN 2 - SID',
        'MFN 2 - Add code',
        'MFN 2 - Duty',
        'MFN 2 - Measure type',
      ].freeze

      TAB_COLOR = '00ff00'.freeze

      CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

      COLUMN_WIDTHS = [
        25, # Commodity code
        40, # Headline
        20, # MFN 1 - SID
        20, # MFN 1 - Add code
        20, # MFN 1 - Duty
        20, # MFN 1 - Measure type
        20, # MFN 2 - SID
        20, # MFN 2 - Add code
        20, # MFN 2 - Duty
        20, # MFN 2 - Measure type
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

        each_declarable do |declarable|
          row = build_row_for(declarable)

          acc << row unless row.nil?
        end

        acc
      end

      def each_declarable
        each_chapter(eager: Differences::GOODS_NOMENCLATURE_OVERVIEW_MEASURE_WITH_COMPONENTS_EAGER) do |eager_chapter|
          eager_chapter.descendants.each do |chapter_descendant|
            next unless chapter_descendant.declarable?

            candidate_mfns = chapter_descendant.applicable_overview_measures.select do |measure|
              measure.measure_type_id.in?(MeasureType::THIRD_COUNTRY)
            end

            # TODO: ME16 violations (mixture of additional code and
            #      non-additional code measures of the same type) are acceptable
            #      for the present moment.
            #
            #      This is because these aren't going to get fixed in the short term.
            any_additional_code_measures = candidate_mfns.any?(&:additional_code_sid)
            all_different_type_measures = candidate_mfns.map(&:measure_type_id).uniq.size == 2 && candidate_mfns.size == 2

            next if any_additional_code_measures || all_different_type_measures

            yield chapter_descendant if candidate_mfns.many?
          end
        end
      end

      def build_row_for(declarable)
        mfn_measures = declarable.applicable_overview_measures.select do |measure|
          measure.measure_type_id.in?(MeasureType::THIRD_COUNTRY)
        end

        mfn_measure_1 = mfn_measures.first
        mfn_measure_2 = mfn_measures.second

        [
          declarable.goods_nomenclature_item_id,
          declarable.description,
          mfn_measure_1.measure_sid,
          "#{mfn_measure_1.additional_code_type_id}#{mfn_measure_1.additional_code_id}",
          mfn_measure_1.duty_expression,
          mfn_measure_1.measure_type_id,
          mfn_measure_2.measure_sid,
          "#{mfn_measure_2.additional_code_type_id}#{mfn_measure_2.additional_code_id}",
          mfn_measure_2.duty_expression,
          mfn_measure_2.measure_type_id,
        ]
      end
    end
  end
end
