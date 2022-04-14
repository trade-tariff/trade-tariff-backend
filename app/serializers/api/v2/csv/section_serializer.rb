module Api
  module V2
    module Csv
      class SectionSerializer
        include CsvSerializer

        columns :id,
                :numeral,
                :title,
                :position,
                :chapter_from,
                :chapter_to
      end
    end
  end
end
