module Api
  module V2
    module Csv
      class GoodsNomenclatureSerializer
        include Api::Shared::CsvSerializer

        column :goods_nomenclature_sid, column_name: 'SID'
        column :goods_nomenclature_item_id, column_name: 'Goods Nomenclature Item ID'
        column :number_indents, column_name: 'Indents'
        column :description, column_name: 'Description'
        column :producline_suffix, column_name: 'Product Line Suffix'

        column :href, column_name: 'Href' do |goods_nomenclature, _options|
          Api::V2::GoodsNomenclaturesController
            .api_path_builder(goods_nomenclature, check_for_subheadings: true)
        end

        column :formatted_description, column_name: 'Formatted description'
        column :validity_start_date, column_name: 'Start date'
        column :validity_end_date, column_name: 'End date'
        column :declarable, column_name: 'Declarable', &:declarable?

        column :parent_sid, column_name: 'Parent SID' do |goods_nomenclature|
          goods_nomenclature.parent&.goods_nomenclature_sid
        end
      end
    end
  end
end
