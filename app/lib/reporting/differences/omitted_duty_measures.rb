module Reporting
  class Differences
    class OmittedDutyMeasures
      delegate :workbook,
               :regular_style,
               :bold_style,
               :each_chapter,
               to: :report

      WORKSHEET_NAME = 'Omitted duties'.freeze

      INCLUDED_MEASURE_TYPES = Set.new(
        %w[
          112
          115
          117
          119
          142
          143
          145
          146
        ],
      )

      EXCLUDED_GEOGRAPHICAL_AREA_IDS = Set.new(
        %w[
          1080
          2005
          2020
          2027
          UA
        ],
      ).freeze

      HEADER_ROW = [
        'Commodity code',
        'Geographical area id',
        'Measure type id',
        'dd/mm',
        'Order number',
        'Additional_ code',
      ].freeze

      TAB_COLOR = '00ff00'.freeze

      CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

      COLUMN_WIDTHS = [
        30, # Commodity code
        20, # Geographical area id
        20, # Measure type id
        20, # dd/mm
        20, # Order number
        20, # Additional code
      ].freeze

      AUTOFILTER_CELL_RANGE = 'A1:F1'.freeze
      FROZEN_VIEW_STARTING_CELL = 'A2'.freeze

      def initialize(report)
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

      def past_as_of
        @past_as_of ||= (Time.zone.today - 1.year).iso8601
      end

      def today_as_of
        @today_as_of ||= Time.zone.today.iso8601
      end

      def each_row
        start_time = Time.zone.now

        non_continuous_measure_sids = Set.new

        each_chapter_from_past do |chapter|
          current_chapter_measures = current_declarables_and_measures_for_chapter(chapter)

          past_declarables_and_measures_for_chapter(chapter).each do |declarable, past_measures|
            current_declarable_measures = current_chapter_measures[declarable]

            next if current_declarable_measures.nil?

            past_measures.each do |past_measure, _|
              next if current_declarable_measures.include?(past_measure)
              next if non_continuous_measure_sids.include?(past_measure.measure_sid)

              non_continuous_measure_sids << past_measure.measure_sid
              yield build_row_for(past_measure)
            end
          end
        end

        end_time = Time.zone.now
        Rails.logger.debug("Time taken for each_row: #{end_time - start_time} seconds")
      end

      def each_chapter_from_past(&block)
        TimeMachine.at(past_as_of) do
          Chapter
            .non_hidden
            .non_classifieds
            .actual
            .all
            .each(&block)
        end
      end

      def current_declarables_and_measures_for_chapter(chapter)
        start_time = Time.zone.now
        acc = {}

        Rails.logger.debug("Processing current_declarables_and_measures for date: #{today_as_of}")

        each_declarable_and_measures_for_chapter(chapter, today_as_of) do |declarable|
          declarable.applicable_measures.each do |measure|
            measure = PresentedMeasure.new(measure)

            next unless INCLUDED_MEASURE_TYPES.include?(measure.measure_type_id)
            next if EXCLUDED_GEOGRAPHICAL_AREA_IDS.include?(measure.geographical_area_id)

            acc[declarable] ||= Set.new
            acc[declarable] << measure
          end
        end

        end_time = Time.zone.now
        Rails.logger.debug("Time taken for current_declarables_and_measures: #{end_time - start_time} seconds")

        acc
      end

      def past_declarables_and_measures_for_chapter(chapter)
        start_time = Time.zone.now
        acc = {}

        Rails.logger.debug("Processing past_declarables_and_measures for date: #{past_as_of}")

        each_declarable_and_measures_for_chapter(chapter, past_as_of) do |declarable|
          declarable.applicable_measures.each do |measure|
            measure = PresentedMeasure.new(measure)

            next unless INCLUDED_MEASURE_TYPES.include?(measure.measure_type_id)
            next if EXCLUDED_GEOGRAPHICAL_AREA_IDS.include?(measure.geographical_area_id)

            acc[declarable] ||= Set.new
            acc[declarable] << measure
          end
        end
        end_time = Time.zone.now
        Rails.logger.debug("Time taken for past_declarables_and_measures: #{end_time - start_time} seconds")

        acc
      end

      def each_declarable_and_measures_for_chapter(chapter, as_of)
        start_time = Time.zone.now
        TimeMachine.at(as_of) do
          Chapter
            .actual
            .where(goods_nomenclature_item_id: chapter.goods_nomenclature_item_id,
                   producline_suffix: chapter.producline_suffix)
            .non_hidden
            .non_classifieds
            .eager(Differences::GOODS_NOMENCLATURE_MEASURE_EAGER)
            .take
            .descendants
            .select(&:declarable?)
            .each do |chapter_descendant|
              yield PresentedDeclarable.new(chapter_descendant)
            end
        end

        end_time = Time.zone.now
        Rails.logger.debug("Time taken for each_declarable: #{end_time - start_time} seconds")
      end

      def build_row_for(measure)
        [
          measure.goods_nomenclature_item_id,
          measure.geographical_area_id,
          measure.measure_type_id,
          measure.effective_start_date.strftime('%d/%m'),
          measure.ordernumber,
          measure.additional_code,
        ]
      end

      class PresentedDeclarable < WrapDelegator
        def hash
          @hash ||= [
            goods_nomenclature_item_id,
            producline_suffix,
          ].hash
        end

        def eql?(other)
          hash == other.hash
        end
      end

      class PresentedMeasure < WrapDelegator
        def hash
          @hash ||= [
            goods_nomenclature_item_id,
            geographical_area_id,
            measure_type_id,
            ordernumber,
            additional_code,
          ].hash
        end

        def eql?(other)
          hash == other.hash
        end

        def additional_code
          "#{additional_code_type_id}#{additional_code_id}".presence || nil
        end
      end
    end
  end
end
