module Api
  module V2
    module Csv
      class GoodsNomenclatureSerializer
        include CsvSerializer

        column :goods_nomenclature_sid, column_name: 'SID'
        column :goods_nomenclature_item_id, column_name: 'Goods Nomenclature Item ID'
        column :number_indents, column_name: 'Indents'
        column :description, column_name: 'Description'
        column :producline_suffix, column_name: 'Product Line Suffix'

        column :href, column_name: 'Href' do |goods_nomenclature, _options|
          Api::V2::GoodsNomenclaturesController.api_path_builder(goods_nomenclature)
        end
      end
    end
  end
end
