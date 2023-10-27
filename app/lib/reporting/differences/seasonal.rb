module Reporting
  class Differences
    class Seasonal
      delegate :workbook,
               :regular_style,
               :bold_style,
               :each_chapter,
               to: :report

      WORKSHEET_NAME = 'Seasonal duties'.freeze

      HEADER_ROW = [
        'Commodity code',
        'Geo area',
        'Measure type',
        'Start date',
        'End date',
        'Duty status',
      ].freeze

      TAB_COLOR = '00ff00'.freeze

      CELL_TYPES = Array.new(HEADER_ROW.size, :string).freeze

      COLUMN_WIDTHS = ([20] * 5 + [40]).freeze

      AUTOFILTER_CELL_RANGE = 'A5:F5'.freeze
      FROZEN_VIEW_STARTING_CELL = 'A6'.freeze

      METRIC = 'Seasonal duties'.freeze
      SUBTEXT = 'Seasonal duties that should be in place (according to the reference documents) but cannot be found'.freeze

      DUTY_STATUSES = {
        start_date: 'Different start date, same end date',
        no_duty: 'No duty found',
      }.freeze

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

        each_seasonal_measure do |measure|
          row = build_row_for(measure)

          acc << row unless row.nil?
        end

        acc
      end

      def build_row_for(measure)
        [
          measure.goods_nomenclature_item_id,
          measure.geographical_area_id,
          measure.measure_type_id,
          measure.validity_start_date,
          measure.validity_end_date,
          measure.failed_duty_status,
        ]
      end

      def each_seasonal_measure
        seasonal_measures.map do |seasonal_measure|
          applicable_measure = applicable_measures[seasonal_measure]

          if applicable_measure
            seasonal_measure.failed_duty_status = DUTY_STATUSES[:start_date] if applicable_measure.validity_start_date != seasonal_measure.validity_start_date
          else
            seasonal_measure.failed_duty_status = DUTY_STATUSES[:no_duty]
          end

          yield seasonal_measure if seasonal_measure.failed_duty_status.present?
        end
      end

      def applicable_measures
        @applicable_measures ||= begin
          measures = Measure
          .with_seasonal_measures(measure_type_ids, geographical_area_ids)
          .all

          PresentedMeasure.wrap(measures).index_by { |measure| measure }
        end
      end

      def seasonal_measures
        @seasonal_measures ||= CSV.parse(File.read('db/seasonal_measures.csv'), headers: true).map do |row|
          PresentedSeasonalMeasure.new(row)
        end
      end

      def measure_type_ids
        seasonal_measures.pluck(:measure_type_id).uniq
      end

      def geographical_area_ids
        seasonal_measures.pluck(:geographical_area_id).uniq
      end

      class PresentedMeasure < WrapDelegator
        def hash
          [
            goods_nomenclature_item_id,
            geographical_area_id,
            measure_type_id,
            self[:validity_end_date].to_date.iso8601,
          ].hash
        end

        def eql?(other)
          hash == other.hash
        end
      end

      class PresentedSeasonalMeasure
        attr_reader :goods_nomenclature_item_id,
                    :geographical_area_id,
                    :measure_type_id,
                    :from,
                    :to

        attr_accessor :failed_duty_status

        def initialize(row)
          @goods_nomenclature_item_id = row['goods_nomenclature_item_id']
          @geographical_area_id = row['geographical_area_id']
          @measure_type_id = row['measure_type_id']
          @from = row['from']
          @to = row['to']
        end

        def [](key)
          public_send(key)
        end

        def hash
          [
            goods_nomenclature_item_id,
            geographical_area_id,
            measure_type_id,
            validity_end_date.iso8601,
          ].hash
        end

        def eql?(other)
          hash == other.hash
        end

        def validity_start_date
          "#{from}/#{Time.zone.today.year}".to_date
        end

        def validity_end_date
          candidate_to = if to == '29/02' && !Time.zone.today.leap?
                           "28/02/#{Time.zone.today.year}"
                         elsif to == '28/02' && Time.zone.today.leap?
                           "29/02/#{Time.zone.today.year}"
                         else
                           "#{to}/#{Time.zone.today.year}"
                         end.to_date

          delta = candidate_to - validity_start_date

          if delta.negative?
            candidate_to + 1.year
          else
            candidate_to
          end
        end
      end
    end
  end
end
