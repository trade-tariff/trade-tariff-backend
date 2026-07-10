module Api
  module V3
    class HeadingSerializer
      def initialize(heading)
        @heading = heading
      end

      def call
        {
          goods_nomenclature_sid: @heading.goods_nomenclature_sid,
          goods_nomenclature_item_id: @heading.goods_nomenclature_item_id,
          description: @heading.description,
          formatted_description: @heading.formatted_description,
          validity_start_date: @heading.validity_start_date,
          validity_end_date: @heading.validity_end_date,
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
