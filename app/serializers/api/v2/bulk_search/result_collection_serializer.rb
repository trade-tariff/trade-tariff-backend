module Api
  module V2
    module BulkSearch
      class ResultCollectionSerializer
        include JSONAPI::Serializer

        set_type :result_collection

        attributes :status,
                   :message

        has_many :searches, serializer: Api::V2::BulkSearch::SearchSerializer
      end
    end
  end
end
