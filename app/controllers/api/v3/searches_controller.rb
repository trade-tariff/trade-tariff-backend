module Api
  module V3
    class SearchesController < BaseController
      def search
        results = SearchService.new(Api::V3::SearchSerializationService.new, params).to_json
        render json: results
      end
    end
  end
end
