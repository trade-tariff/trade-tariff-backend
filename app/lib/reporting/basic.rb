module Reporting
  class Basic
    extend Reporting::Reportable

    MEASURE_EAGER = [
      { measure_type: :measure_type_description },
      {
        measure_components: [
          { duty_expression: :duty_expression_description },
          { measurement_unit: %i[measurement_unit_description measurement_unit_abbreviations] },
          :monetary_unit,
          :measurement_unit_qualifier,
        ],
      },
      { additional_code: :additional_code_descriptions },
    ].freeze

    GOODS_NOMENCLATURE_EAGER = [
      { ancestors: [{ overview_measures: MEASURE_EAGER }] },
      { overview_measures: MEASURE_EAGER },
      :children,
      :goods_nomenclature_descriptions,
    ].freeze

    ADDITIONAL_CODE_PRIORITY = Hash.new(100) # Handle uncaptured additional codes
    ADDITIONAL_CODE_PRIORITY.merge!(
      nil => 0,
      '2501' => 1,
      '2601' => 2,
      '2701' => 3,
      '2500' => 4,
      '2600' => 5,
      '2700' => 6,
      '2702' => 7,
      '2704' => 8,
    ).freeze

    MFN_MEASURE_PRIORITY = {
      '103' => 1,
      '105' => 2,
    }.freeze

    HEADER_ROW = [
      'Commodity code',
      'Description',
      'Third country duty',
      'Supplementary unit',
    ].freeze

    COMPLEX_MEASURE_TEXT = 'See measure conditions'.freeze

    class << self
      def generate
        rows = []

        TimeMachine.now do
          goods_nomenclatures.each do |goods_nomenclature|
            rows << build_row_for(goods_nomenclature)
          end

          csv_data = CSV.generate(write_headers: true, headers: HEADER_ROW) do |csv|
            rows.each do |row|
              csv << row
            end
          end

          if rows.any?
            File.write(File.basename(object_key), csv_data) if Rails.env.development?

            if Rails.env.production?
              object.put(
                body: csv_data,
                content_type: 'text/csv',
              )
            end
          end

          Rails.logger.debug("Query count: #{::SequelRails::Railties::LogSubscriber.count}")
        end
      end

      private

      def build_row_for(goods_nomenclature)
        overview_measures = goods_nomenclature.applicable_overview_measures
        third_country_measures = overview_measures.select(&:third_country?)
        supplementary_measure = overview_measures.find(&:supplementary?)
        third_country_measure = if third_country_measures.any?
                                  third_country_measures.min_by do |measure|
                                    MFN_MEASURE_PRIORITY[measure.measure_type_id] +
                                      ADDITIONAL_CODE_PRIORITY[measure.additional_code&.code]
                                  end
                                end

        third_country_duty = third_country_measure&.duty_expression.presence || COMPLEX_MEASURE_TEXT

        row = []
        row << goods_nomenclature.goods_nomenclature_item_id
        row << goods_nomenclature&.goods_nomenclature_description&.description_plain&.tr("\u00A0", ' ')
        row << third_country_duty
        row << supplementary_measure&.supplementary_unit_duty_expression

        row
      end

      def goods_nomenclatures
        GoodsNomenclature
          .actual
          .declarable
          .eager(GOODS_NOMENCLATURE_EAGER)
          .non_hidden
          .non_classifieds
          .all
      end

      def object_key
        "#{service}/reporting/#{year}/#{month}/#{day}/tariff_data_basic_#{service}_#{now.strftime('%Y_%m_%d')}.csv"
      end
    end
  end
end
