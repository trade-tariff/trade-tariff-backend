module Api
  module V2
    module Csv
      class HeadingSerializer
        include Api::Shared::CsvSerializer

        columns :goods_nomenclature_item_id,
                :goods_nomenclature_sid

        column  :declarable, &:declarable?

        columns :description,
                :description_plain,
                :formatted_description,
                :producline_suffix

        column  :leaf, &:leaf?
      end
    end
  end
end
