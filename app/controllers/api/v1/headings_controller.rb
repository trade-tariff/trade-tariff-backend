module Api
  module V1
    class HeadingsController < ApiController
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
            :monetary_unit,
            :measurement_unit_qualifier,
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
            {
              measure_condition_components: %i[measure_condition
                                               duty_expression
                                               measurement_unit
                                               monetary_unit
                                               measurement_unit_qualifier],
            },
          ],
        },
        { quota_order_number: :quota_definition },
        { excluded_geographical_areas: :geographical_area_descriptions },
        :additional_code,
        :full_temporary_stop_regulations,
        :measure_partial_temporary_stops,
      ].freeze

      DECLARABLE_EAGER = [
        :goods_nomenclature_descriptions,
        {
          chapter: [
            :goods_nomenclature_descriptions,
            :guides,
            :chapter_note,
            { sections: :section_note },
          ],
          ns_measures: MEASURE_EAGER,
          ns_ancestors: [{ ns_measures: MEASURE_EAGER }],
        },
      ].freeze

      NON_DECLARABLE_EAGER = [
        :goods_nomenclature_descriptions,
        {
          chapter: [
            :goods_nomenclature_descriptions,
            :guides,
            :chapter_note,
            { sections: :section_note },
          ],
          ns_descendants: %i[
            ns_parent
            goods_nomenclature_descriptions
          ],
        },
      ].freeze

      def show
        @heading = heading
        @heading_cache_key = "heading-#{@heading.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}-#{@heading.ns_declarable?}"
        respond_with @heading
      end

      def changes
        @heading = heading

        key = "heading-#{@heading.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}/changes"
        @changes = Rails.cache.fetch(key, expires_at: actual_date.end_of_day) do
          ChangeLog.new(@heading.changes.where do |o|
            o.operation_date <= actual_date
          end)
        end

        render 'api/v1/changes/changes'
      end

      def tree
        @heading = non_declarable_heading
      end

      private

      def heading
        @heading ||= if declarable?
                       declarable_heading
                     else
                       non_declarable_heading
                     end
      end

      def declarable_heading
        @declarable_heading ||= shared_heading_scope.eager(DECLARABLE_EAGER).take
      end

      def non_declarable_heading
        @non_declarable_heading ||= shared_heading_scope.eager(NON_DECLARABLE_EAGER).take
      end

      def shared_heading_scope
        Heading
          .actual
          .non_hidden
          .non_grouping
          .by_code(params[:id])
      end

      def declarable?
        shared_heading_scope
          .take
          .ns_declarable?
      end
    end
  end
end
