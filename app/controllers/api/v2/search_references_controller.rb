module Api
  module V2
    class SearchReferencesController < ApiController
      def index
        render json: serialized_search_references
      end

      private

      def serialized_search_references
        Api::V2::SearchReferenceSerializer.new(search_references).serializable_hash
      end

      def search_references
        @search_references ||= SearchReference
          .for_letter(letter)
          .eager(:referenced)
          .all
      end

      def letter
        params.dig(:query, :letter) || ''
      end
    end
  end
end
