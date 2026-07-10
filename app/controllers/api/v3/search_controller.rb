module Api
  module V3
    class SearchController < BaseController
      def search
        results = SearchService.new(Api::V2::SearchSerializationService.new, params).to_json
        render json: results
      end
    end
  end
end
