module Api
  module V2
    class CommoditiesController < ApiController
      before_action :find_commodity, only: %i[show changes]

      def show
        @commodity_cache_key = "commodity-#{@commodity.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}"
        serializable_hash = Rails.cache.fetch('_' + @commodity_cache_key, expires_in: TradeTariffBackend.seconds_till_6am) do
          @measures = MeasurePresenter.new(
            @commodity.measures_dataset.eager(
              { footnotes: :footnote_descriptions },
              { measure_type: :measure_type_description },
              { measure_components: [{ duty_expression: :duty_expression_description },
                                     { measurement_unit: %i[measurement_unit_description measurement_unit_abbreviations] },
                                     { measure: { measure_type: :measure_type_description } },
                                     :monetary_unit,
                                     :measurement_unit_qualifier] },
              { measure_conditions: [{ measure_action: :measure_action_description },
                                     { certificate: :certificate_descriptions },
                                     { certificate_type: :certificate_type_description },
                                     { measurement_unit: %i[measurement_unit_description measurement_unit_abbreviations] },
                                     :monetary_unit,
                                     :measurement_unit_qualifier,
                                     { measure_condition_code: :measure_condition_code_description },
                                     { measure_condition_components: [{ measurement_unit: %i[measurement_unit_description measurement_unit_abbreviations] },
                                                                      :measure_condition,
                                                                      :duty_expression,
                                                                      :monetary_unit,
                                                                      :measurement_unit_qualifier] }] },
              { quota_order_number: { quota_definition: %i[quota_balance_events quota_suspension_periods quota_blocking_periods] } },
              { excluded_geographical_areas: :geographical_area_descriptions },
              { geographical_area: [:geographical_area_descriptions,
                                    { contained_geographical_areas: :geographical_area_descriptions }] },
              { additional_code: :additional_code_descriptions },
              :footnotes,
              :base_regulation,
              :modification_regulation,
              :full_temporary_stop_regulations,
              :measure_partial_temporary_stops,
            ).all, @commodity
          ).validate!

          presenter = Api::V2::Commodities::CommodityPresenter.new(@commodity, @measures)
          options = { is_collection: false }
          options[:include] = [:section,
                               :chapter,
                               'chapter.guides',
                               :heading,
                               :ancestors,
                               :footnotes,
                               :import_measures,
                               'import_measures.duty_expression',
                               'import_measures.measure_type',
                               'import_measures.legal_acts',
                               'import_measures.suspending_regulation',
                               'import_measures.measure_conditions',
                               'import_measures.measure_conditions.measure_condition_components',
                               'import_measures.measure_components',
                               'import_measures.national_measurement_units',
                               'import_measures.geographical_area',
                               'import_measures.geographical_area.contained_geographical_areas',
                               'import_measures.excluded_geographical_areas',
                               'import_measures.footnotes',
                               'import_measures.additional_code',
                               'import_measures.order_number',
                               'import_measures.order_number.definition',
                               :export_measures,
                               'export_measures.duty_expression',
                               'export_measures.measure_type',
                               'export_measures.legal_acts',
                               'export_measures.suspending_regulation',
                               'export_measures.measure_conditions',
                               'export_measures.measure_conditions.measure_condition_components',
                               'export_measures.measure_components',
                               'export_measures.national_measurement_units',
                               'export_measures.geographical_area',
                               'export_measures.geographical_area.contained_geographical_areas',
                               'export_measures.excluded_geographical_areas',
                               'export_measures.footnotes',
                               'export_measures.additional_code',
                               'export_measures.order_number',
                               'export_measures.order_number.definition']
          Api::V2::Commodities::CommoditySerializer.new(presenter, options).serializable_hash
        end

        render json: serializable_hash
      end

      def changes
        @changes = ChangeLog.new(@commodity.changes.where do |o|
                                   o.operation_date <= actual_date
                                 end)

        options = {}
        options[:include] = [:record, 'record.geographical_area', 'record.measure_type']
        render json: Api::V2::Changes::ChangeSerializer.new(@changes.changes, options).serializable_hash
      end

      private

      def find_commodity
        @commodity = Commodity.actual
                              .declarable
                              .by_code(params[:id])
                              .eager(:goods_nomenclature_indents, :goods_nomenclature_descriptions, :footnotes)
                              .take

        raise Sequel::RecordNotFound if @commodity.children.any?
        raise Sequel::RecordNotFound if @commodity.goods_nomenclature_item_id.in? HiddenGoodsNomenclature.codes
      end
    end
  end
end
