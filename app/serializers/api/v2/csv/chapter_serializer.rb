module Api
  module V2
    module Csv
      class ChapterSerializer
        include CsvSerializer

        columns :goods_nomenclature_sid,
                :goods_nomenclature_item_id,
                :formatted_description
      end
    end
  end
end
