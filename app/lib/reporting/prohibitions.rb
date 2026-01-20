module Reporting
  class Prohibitions
    extend Reporting::Reportable

    MEASURE_EAGER = [
      :base_regulation,
      :modification_regulation,
      { quota_definition: :quota_balance_events },
      { measure_type: :measure_type_description },
      {
        measure_components: [
          { duty_expression: :duty_expression_description },
          { measurement_unit: %i[measurement_unit_description measurement_unit_abbreviations] },
          { monetary_unit: :monetary_unit_description },
          :measurement_unit_qualifier,
        ],
      },
      { additional_code: :additional_code_descriptions },
      { geographical_area: :geographical_area_descriptions },
      { measure_excluded_geographical_areas: [{ geographical_area: :geographical_area_descriptions }] },
      :footnotes,
      :measure_conditions,
    ].freeze

    GOODS_NOMENCLATURE_EAGER = [
      {
        ancestors: [{ measures: MEASURE_EAGER }],
        descendants: [{ measures: MEASURE_EAGER }, :goods_nomenclature_descriptions],
        measures: MEASURE_EAGER,
      },
      :goods_nomenclature_descriptions,
    ].freeze

    RELEVANT_MEASURE_TYPE_SERIES_IDS = %w[
      A
      B
    ].freeze

    HEADER_ROW = %w[
      trackedmodel_ptr_id
      commodity__sid
      commodity__code
      commodity__indent
      commodity__description
      measure__sid
      measure__type__id
      measure__type__description
      measure__additional_code__code
      measure__additional_code__description
      measure__duty_expression
      measure__effective_start_date
      measure__effective_end_date
      measure_reduction_indicator
      measure__footnotes
      measure__conditions
      measure__geographical_area__sid
      measure__geographical_area__id
      measure__geographical_area__description
      measure__excluded_geographical_areas__ids
      measure__excluded_geographical_areas__descriptions
      measure__quota__order_number
      measure__quota__available
      measure__regulation__id
      measure__regulation__url
    ].freeze

    COLUMN_WIDTHS = [
      20,  # trackedmodel_ptr_id
      20,  # commodity__sid
      20,  # commodity__code
      20,  # commodity__indent
      50,  # commodity__description
      20,  # measure__sid
      20,  # measure__type__id
      30,  # measure__type__description
      20,  # measure__additional_code__code
      20,  # measure__additional_code__description
      20,  # measure__duty_expression
      20,  # measure__effective_start_date
      20,  # measure__effective_end_date
      20,  # measure_reduction_indicator
      20,  # measure__footnotes
      100, # measure__conditions
      20,  # measure__geographical_area__sid
      20,  # measure__geographical_area__id
      20,  # measure__geographical_area__description
      20,  # measure__excluded_geographical_areas__ids
      20,  # measure__excluded_geographical_areas__descriptions
      20,  # measure__quota__order_number
      20,  # measure__quota__available
      20,  # measure__regulation__id
      30,  # measure__regulation__url
    ].freeze

    class << self
      def generate
        workbook = if Rails.env.development?
                     FileUtils.rm(filename) if File.exist?(filename)
                     FastExcel.open(filename, constant_memory: true)
                   else
                     FastExcel.open(constant_memory: true)
                   end

        bold_format = workbook.add_format(bold: true)

        worksheet = workbook.add_worksheet(Time.zone.today.iso8601)

        COLUMN_WIDTHS.each_with_index do |width, index|
          worksheet.set_column_width(index, width)
        end

        worksheet.append_row(HEADER_ROW, bold_format)
        worksheet.freeze_panes(1, 0)
        worksheet.autofilter(0, 1, 1, 25)

        each_declarable_and_measure do |declarable, measure|
          row = build_row_for(declarable, measure)
          worksheet.append_row(row)
        end

        workbook.close

        if Rails.env.production?
          object.put(
            body: workbook.read_string,
            content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          )
        end

        Rails.logger.debug("Query count: #{::SequelRails::Railties::LogSubscriber.count}")
      end

      private

      def build_row_for(declarable, measure)
        HEADER_ROW.map do |header|
          if declarable.respond_to?(header)
            declarable.public_send(header)
          else
            measure.public_send(header)
          end
        end
      end

      def each_declarable_and_measure
        index = 1
        TimeMachine.now do
          each_declarable do |declarable|
            measures = DeclarableDuties::PresentedMeasure.wrap(declarable.applicable_measures)
            measures = measures.sort

            measures.each do |measure|
              next unless measure.measure_type&.measure_type_series_id&.in?(RELEVANT_MEASURE_TYPE_SERIES_IDS)

              measure.trackedmodel_ptr_id = index

              yield declarable, measure

              index += 1
            end
          end
        end
      end

      def each_declarable
        each_chapter do |eager_chapter|
          eager_chapter.descendants.each do |chapter_descendant|
            next unless chapter_descendant.declarable?

            yield DeclarableDuties::PresentedDeclarable.new(chapter_descendant)
          end
        end
      end

      def each_chapter
        Chapter
          .actual
          .non_hidden
          .non_classifieds
          .all
          .each do |chapter|
          eager_chapter = Chapter.actual
            .where(goods_nomenclature_sid: chapter.goods_nomenclature_sid)
            .eager(GOODS_NOMENCLATURE_EAGER)
            .take

          yield eager_chapter
        end
      end

      def object_key
        "#{service}/reporting/#{year}/#{month}/#{day}/declarable_commodities_with_prohibition_measures_#{service}_#{now.strftime('%Y_%m_%d')}.xlsx"
      end

      def filename
        File.basename(object_key)
      end
    end
  end
end
