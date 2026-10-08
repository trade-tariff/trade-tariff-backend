module Api
  module Admin
    class SearchReferencesController < AdminController
      def index
        search_references = SearchReference.for_usage(usage_filter).for_letter(letter).all

        render json: Api::Admin::SearchReferences::SearchReferenceListSerializer.new(search_references).serializable_hash
      end

    private

      def letter
        params.dig(:query, :letter) || ''
      end

      def usage_filter
        usage = params.dig(:filter, :usage)
        SearchReference::USAGE_FILTERS.include?(usage) ? usage : SearchReference::SEARCH_USAGE
      end
    end
  end
end
