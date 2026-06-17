module HeadingService
  module Serialization
    class DeclarableService
      include DeclarableSerialization
      include JsonapiQueryOptions

      MEASURE_EAGER = [
        {
          geographical_area: [
            :geographical_area_descriptions,
            { contained_geographical_areas: :geographical_area_descriptions },
          ],
        },
        { footnotes: :footnote_descriptions },
        { measure_type: :measure_type_description },
        {
          measure_components: [
            { duty_expression: :duty_expression_description },
            { measurement_unit: :measurement_unit_description },
            { measurement_unit_qualifier: :measurement_unit_qualifier_description },
            :monetary_unit,
          ],
        },
        {
          measure_conditions: [
            { measure_action: :measure_action_description },
            { certificate: :certificate_descriptions },
            { certificate_type: :certificate_type_description },
            { measurement_unit: :measurement_unit_description },
            :monetary_unit,
            :measurement_unit_qualifier,
            { measure_condition_code: :measure_condition_code_description },
            { measure_condition_components: %i[measure_condition
                                               duty_expression
                                               measurement_unit
                                               monetary_unit
                                               measurement_unit_qualifier] },
          ],
        },
        { quota_order_number: :quota_definition },
        {
          excluded_geographical_areas: [
            :geographical_area_descriptions,
            :contained_geographical_areas,
            { referenced: :contained_geographical_areas },
          ],
        },
        :additional_code,
        :full_temporary_stop_regulations,
        :measure_partial_temporary_stops,
      ].freeze
      def self.chapter_note_eager_load
        TradeTariffBackend.promote_customs_tariff_notes? ? :customs_tariff_chapter_note : :chapter_note
      end

      def self.section_note_eager_load
        TradeTariffBackend.promote_customs_tariff_notes? ? :customs_tariff_section_note : :section_note
      end

      BASE_HEADING_EAGER = [
        {
          measures: MEASURE_EAGER,
          ancestors: [{ measures: MEASURE_EAGER }],
        },
        :goods_nomenclature_descriptions,
      ].freeze

      OPTIONS = {
        is_collection: false,
        include: DECLARABLE_INCLUDES,
      }.freeze

      attr_reader :goods_nomenclature_sid, :filters

      delegate :serializable_hash, to: :serializer

      def initialize(heading, filters)
        @goods_nomenclature_sid = heading.goods_nomenclature_sid
        @filters = filters
      end

    private

      def presented
        @presented ||= \
          Api::V2::Headings::DeclarableHeadingPresenter.new(heading, filtered_measures)
      end

      def serializer
        @serializer ||= \
          Api::V2::Headings::DeclarableHeadingSerializer.new(presented, OPTIONS)
      end

      def filtered_measures
        MeasureCollection.new(measures, filters).filter
      end

      def heading
        @heading ||= Heading.where(goods_nomenclature_sid:).eager(*heading_eager_loads).take
      end

      def measures
        heading.applicable_measures
      end

      def heading_eager_loads
        [
          *BASE_HEADING_EAGER,
          *chapter_eager_loads,
        ]
      end

      def chapter_eager_loads
        return [] unless heading_chapter_data_requested?

        chapter_eager_load = []
        chapter_eager_load << self.class.chapter_note_eager_load if jsonapi_field_requested?(:chapter, :chapter_note)
        chapter_eager_load << :guides if chapter_guides_requested?
        chapter_eager_load << section_eager_load if heading_section_data_requested?

        return [:chapter] if chapter_eager_load.empty?

        [{ chapter: chapter_eager_load }]
      end

      def heading_chapter_data_requested?
        jsonapi_relationship_requested?(:heading, :chapter, default_include: DECLARABLE_INCLUDES) ||
          heading_section_data_requested?
      end

      def heading_section_data_requested?
        jsonapi_relationship_requested?(:heading, :section, default_include: DECLARABLE_INCLUDES)
      end

      def chapter_guides_requested?
        includes = jsonapi_include_requested? ? jsonapi_query_options[:include] : DECLARABLE_INCLUDES
        Array(includes).map(&:to_s).include?('chapter.guides')
      end

      def section_eager_load
        return :sections unless jsonapi_field_requested?(:section, :section_note)

        { sections: [self.class.section_note_eager_load] }
      end
    end
  end
end
