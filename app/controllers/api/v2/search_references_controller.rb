module Api
  module V2
    class SearchReferencesController < ApiController
      time_based_caching

      def index
        return head :bad_request unless SearchReference::USAGE_FILTERS.include?(usage_filter)

        render json: serialized_search_references
      end

    private

      def serialized_search_references
        Api::V2::SearchReferenceSerializer.new(search_references).serializable_hash
      end

      def search_references
        @search_references ||= SearchReference
          .for_usage(usage_filter)
          .for_letter(letter)
          .eager(:referenced)
          .all
      end

      def letter
        query = params[:query]
        return '' unless query.is_a?(ActionController::Parameters)

        query[:letter] || ''
      end

      def usage_filter
        filter = params[:filter]
        return SearchReference::SEARCH_USAGE unless filter.is_a?(ActionController::Parameters)

        filter[:usage].presence || SearchReference::SEARCH_USAGE
      end
    end
  end
end
