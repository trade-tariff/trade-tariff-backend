module Api
  module V2
    module BulkSearch
      class SearchResultSerializer
        include JSONAPI::Serializer

        set_type :search_result

        attributes :number_of_digits, :short_code

        attributes :score, &:presented_score
      end
    end
  end
end
