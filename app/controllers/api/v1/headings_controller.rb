require 'goods_nomenclature_mapper'

module Api
  module V1
    class HeadingsController < ApiController
      before_action :find_heading, only: [:show, :changes]

      def show
        if @heading.declarable?
          @measures = MeasureCollection.new(@heading.measures_dataset.eager({ geographical_area: [:geographical_area_descriptions,
                                                                                                 { contained_geographical_areas: :geographical_area_descriptions }] },
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
                                                                             { measure_condition_components: [:measure_condition,
                                                                                                              :duty_expression,
                                                                                                              :measurement_unit,
                                                                                                              :monetary_unit,
                                                                                                              :measurement_unit_qualifier] }] },
                                                      { quota_order_number: :quota_definition },
                                                      { excluded_geographical_areas: :geographical_area_descriptions },
                                                      :additional_code,
                                                      :full_temporary_stop_regulations,
                                                      :measure_partial_temporary_stops).all, @heading).validate!
        else
          @commodities = GoodsNomenclatureMapper.new(@heading.commodities_dataset.eager(:goods_nomenclature_indents,
                                                                                        :goods_nomenclature_descriptions)
                                                             .all).all

        end

        @heading_cache_key = "heading-#{@heading.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}-#{@heading.declarable?}"
        respond_with @heading
      end

      def changes
        key = "heading-#{@heading.goods_nomenclature_sid}-#{actual_date}-#{TradeTariffBackend.currency}/changes"
        @changes = Rails.cache.fetch(key, expires_at: actual_date.end_of_day) do
          ChangeLog.new(@heading.changes.where { |o|
            o.operation_date <= actual_date
          })
        end

        render 'api/v1/changes/changes'
      end

      def tree
        @heading = Heading.actual
                          .non_grouping
                          .where(goods_nomenclatures__goods_nomenclature_item_id: params[:id])
                          .take
        @commodities = GoodsNomenclatureMapper.new(@heading.commodities_dataset.eager(:goods_nomenclature_indents, :goods_nomenclature_descriptions).all).all
      end

      private

      def find_heading
        @heading = Heading.actual
                          .non_grouping
                          .where(goods_nomenclatures__goods_nomenclature_item_id: heading_id)
                          .take

        raise Sequel::RecordNotFound if @heading.goods_nomenclature_item_id.in? HiddenGoodsNomenclature.codes
      end

      def heading_id
        "#{params[:id]}000000"
      end
    end
  end
end
