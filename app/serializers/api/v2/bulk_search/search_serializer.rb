module Api
  module V2
    module BulkSearch
      class SearchSerializer
        include JSONAPI::Serializer

        set_type :search

        attributes :input_description

        has_many :search_result_ancestors, serializer: Api::V2::BulkSearch::SearchAncestorSerializer
      end
    end
  end
end
