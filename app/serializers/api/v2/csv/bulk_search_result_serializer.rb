module Api
  module V2
    module Csv
      class BulkSearchResultSerializer
        include Api::Shared::CsvSerializer

        columns :input_description,
                :goods_nomenclature_item_id,
                :producline_suffix,
                :goods_nomenclature_class,
                :short_code,
                :score
      end
    end
  end
end
