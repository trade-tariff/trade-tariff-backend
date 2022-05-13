module Api
  module V2
    module Csv
      class GoodsNomenclatureSerializer
        include CsvSerializer

        column :goods_nomenclature_sid
        column :goods_nomenclature_item_id
        column :number_indents
        column :description
        column :producline_suffix

        column :href do |goods_nomenclature, _options|
          Api::V2::GoodsNomenclaturesController.api_path_builder(goods_nomenclature)
        end
      end
    end
  end
end
