module HeadingService
  module Serialization
    class NsNondeclarableService
      OPTIONS = {
        is_collection: false,
        include: [
          :section,
          :chapter,
          'chapter.guides',
          :footnotes,
          :commodities,
          'commodities.overview_measures',
          'commodities.overview_measures.duty_expression',
          'commodities.overview_measures.measure_type',
          'commodities.overview_measures.additional_code',
        ],
      }.freeze

      MEASURES_EAGER_LOAD = {
        measure_components: {
          duty_expression: :duty_expression_description,
          measurement_unit: %i[measurement_unit_description
                               measurement_unit_abbreviations],
          monetary_unit: :monetary_unit_description,
          measurement_unit_qualifier: [],
        },
        measure_type: %i[measure_type_description
                         measure_type_series
                         measure_type_series_description],
        additional_code: [],
      }.freeze

      HEADING_EAGER_LOAD = [
        :goods_nomenclature_descriptions,
        {
          footnotes: :footnote_descriptions,
          ns_overview_measures: MEASURES_EAGER_LOAD,
          ns_ancestors: [
            :goods_nomenclature_descriptions,
            {
              ns_overview_measures: MEASURES_EAGER_LOAD,
              footnotes: :footnote_descriptions,
            },
          ],
          ns_descendants: [
            :goods_nomenclature_descriptions,
            {
              ns_overview_measures: MEASURES_EAGER_LOAD,
              footnotes: :footnote_descriptions,
            },
          ],
        },
      ].freeze

      attr_reader :heading

      delegate :serializable_hash, to: :serializer

      def initialize(heading)
        @heading = heading
      end

    private

      def presented_heading
        Api::V2::Headings::HeadingPresenter.new(eager_loaded_heading)
      end

      def serializer
        Api::V2::Headings::HeadingSerializer
          .new(presented_heading, OPTIONS)
      end

      def eager_loaded_heading
        Heading.actual
               .non_hidden
               .where(goods_nomenclature_sid: heading.goods_nomenclature_sid)
               .eager(*HEADING_EAGER_LOAD)
               .limit(1)
               .all
               .first
      end
    end
  end
end
