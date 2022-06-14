module Api
  module V2
    module Csv
      class ChapterSerializer
        include Api::Shared::CsvSerializer

        columns :goods_nomenclature_sid,
                :goods_nomenclature_item_id,
                :headings_from,
                :headings_to,
                :formatted_description,
                :description
      end
    end
  end
end
