module Api
  module V2
    class BulkSearchesController < ApiController
      def create
        @result = ::BulkSearch.enqueue(bulk_search_params)
        @serialized_result = Api::V2::BulkSearch::ResultCollectionSerializer.new(@result, include: [:searches]).serializable_hash

        render json: @serialized_result, status: @result.http_code
      end

      def show
        @result = ::BulkSearch.find(params[:id])
        @serialized_result = Api::V2::BulkSearch::ResultCollectionSerializer.new(
          @result,
          include: ['searches.search_result_ancestors'],
        ).serializable_hash
        render json: @serialized_result, status: @result.http_code
      end

      def bulk_search_params
        params.require(:data).map do |json|
          json.permit(:type, attributes: [:input_description])
        end
      end
    end
  end
end
