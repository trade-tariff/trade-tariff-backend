module Api
  module Admin
    class SearchReferencesController < AdminController
      def index
        search_references = SearchReference.for_letter(letter).all

        render json: Api::Admin::SearchReferences::SearchReferenceListSerializer.new(search_references).serializable_hash
      end

      private

      def letter
        params.dig(:query, :letter) || ''
      end
    end
  end
end
