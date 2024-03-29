module Api
  module V1
    class CommoditiesController < ApiController
      before_action :find_commodity, only: %i[show changes]

      def show
        @measures = MeasureCollection.new(
          @commodity.measures_dataset.eager(
            { footnotes: :footnote_descriptions },
            { measure_type: :measure_type_description },
            { measure_components: [{ duty_expression: :duty_expression_description },
                                   { measurement_unit: :measurement_unit_description },
                                   :monetary_unit,
                                   :measurement_unit_qualifier] },
            { measure_conditions: [{ measure_action: :measure_action_description },
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
                                                                      measurement_unit_qualifier] }] },
            { quota_order_number: :quota_definition },
            { excluded_geographical_areas: :geographical_area_descriptions },
            { geographical_area: [:geographical_area_descriptions,
                                  { contained_geographical_areas: :geographical_area_descriptions }] },
            :additional_code,
            :full_temporary_stop_regulations,
            :measure_partial_temporary_stops,
          ).all,
        ).filter

        @commodity_cache_key = "commodity-#{@commodity.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}"
        respond_with @commodity
      end

      def changes
        key = "commodity-#{@commodity.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}/changes"
        @changes = Rails.cache.fetch(key, expires_at: actual_date.end_of_day) do
          ChangeLog.new(@commodity.changes.where do |o|
            o.operation_date <= actual_date
          end)
        end

        render 'api/v1/changes/changes'
      end

      private

      def find_commodity
        @commodity = Commodity.actual
                              .non_hidden
                              .declarable
                              .by_code(params[:id])
                              .take
      end
    end
  end
end
