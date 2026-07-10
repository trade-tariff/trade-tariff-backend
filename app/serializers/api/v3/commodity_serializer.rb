module Api
  module V3
    class CommoditySerializer
      def initialize(commodity)
        @commodity = commodity
      end

      def call
        {
          goods_nomenclature_sid: @commodity.goods_nomenclature_sid,
          goods_nomenclature_item_id: @commodity.goods_nomenclature_item_id,
          producline_suffix: @commodity.producline_suffix,
          description: @commodity.description,
          formatted_description: @commodity.formatted_description,
          description_plain: @commodity.description_plain,
          number_indents: @commodity.number_indents,
          bti_url: @commodity.bti_url,
          consigned_from: @commodity.consigned_from,
          validity_start_date: @commodity.validity_start_date,
          validity_end_date: @commodity.validity_end_date,
          has_chemicals: @commodity.has_chemicals,
          declarable: @commodity.declarable?,
        }
      end

      def self.measure_collection(commodity)
        all_measures = commodity.measures
        import_measures = all_measures.select(&:import).map { |m| serialize_measure(m) }
        export_measures = all_measures.select(&:export).map { |m| serialize_measure(m) }
        total = import_measures.size + export_measures.size

        {
          import_measures:,
          export_measures:,
          meta: { total: },
        }
      end

      def self.serialize_measure(measure)
        {
          id: measure.measure_sid,
          effective_start_date: measure.effective_start_date,
          effective_end_date: measure.effective_end_date,
          excise: measure.excise?,
          vat: measure.vat?,
          reduction_indicator: measure.reduction_indicator,
          measure_type_id: measure.measure_type_id,
          geographical_area_id: measure.geographical_area_id,
          additional_code: measure.additional_code_id,
          order_number: measure.ordernumber,
        }
      end
    end
  end
end
