module Api
  module V2
    class SearchReferencesController < ApiController
      include SimpleCaching

      def index
        search_references = SearchReference.for_letter(letter).all

        render json: Api::V2::SearchReferenceSerializer.new(search_references).serializable_hash
      end

      private

      def letter
        params.dig(:query, :letter) || ''
      end
    end
  end
end
