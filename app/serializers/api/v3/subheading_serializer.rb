module Api
  module V3
    class SubheadingSerializer
      def initialize(subheading)
        @subheading = subheading
      end

      def call
        {
          goods_nomenclature_sid: @subheading.goods_nomenclature_sid,
          goods_nomenclature_item_id: @subheading.goods_nomenclature_item_id,
          producline_suffix: @subheading.producline_suffix,
          description: @subheading.description,
          formatted_description: @subheading.formatted_description,
          number_indents: @subheading.number_indents,
          validity_start_date: @subheading.validity_start_date,
          validity_end_date: @subheading.validity_end_date,
          declarable: false,
        }
      end

      def self.commodity_collection(descendants)
        list = descendants.map do |c|
          {
            goods_nomenclature_sid: c.goods_nomenclature_sid,
            goods_nomenclature_item_id: c.goods_nomenclature_item_id,
            producline_suffix: c.producline_suffix,
            description: c.description,
            formatted_description: c.formatted_description,
            number_indents: c.number_indents,
            validity_start_date: c.validity_start_date,
            validity_end_date: c.validity_end_date,
            declarable: c.respond_to?(:declarable?) ? c.declarable? : false,
          }
        end
        { data: list, meta: { total: list.size } }
      end
    end
  end
end
