module HeadingService
  module Serialization
    class DeclarableService
      include DeclarableSerialization

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
      HEADING_EAGER = [
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
        @heading ||= Heading.where(goods_nomenclature_sid:).eager(HEADING_EAGER).take
      end

      def measures
        heading.applicable_measures
      end
    end
  end
end
