module Api
  module V2
    module Csv
      class BulkSearchResultSerializer
        include Api::Shared::CsvSerializer

        columns :input_description,
                :number_of_digits,
                :short_code,
                :score
      end
    end
  end
end
