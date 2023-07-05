module Api
  module V2
    module BulkSearch
      class SearchSerializer
        include JSONAPI::Serializer

        set_type :search

        attributes :input_description, :number_of_digits

        has_many :search_results, serializer: Api::V2::BulkSearch::SearchResultSerializer
      end
    end
  end
end
