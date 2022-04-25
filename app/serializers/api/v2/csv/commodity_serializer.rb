module Api
  module V2
    module Csv
      class CommoditySerializer
        include CsvSerializer

        columns :description,
                :number_indents,
                :goods_nomenclature_item_id,
                :declarable,
                :leaf,
                :goods_nomenclature_sid,
                :formatted_description,
                :description_plain,
                :producline_suffix,
                :parent_sid
      end
    end
  end
end
