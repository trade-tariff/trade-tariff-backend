module Api
  module V2
    class BulkSearchesController < ApiController
      include NoCaching

      def create
        @result = ::BulkSearch::ResultCollection.enqueue(bulk_search_params)
        @serialized_result = Api::V2::BulkSearch::ResultCollectionSerializer.new(@result).serializable_hash

        render json: @serialized_result, status: :accepted, location: api_bulk_search_path(@result)
      end

      def show
        @result = ::BulkSearch::ResultCollection.find(params[:id])

        respond_to do |format|
          format.json do
            render json: serialized_json_result, status: @result.http_code
          end
          format.csv do
            filename = "#{TradeTariffBackend.service}-bulk-searches-#{params[:id]}-#{actual_date.iso8601}.csv"

            if @result.completed?
              send_data(
                serialized_csv_result,
                type: 'text/csv; charset=utf-8; header=present',
                disposition: "attachment; filename=#{filename}",
                status: @result.http_code,
              )
            else
              render plain: nil, status: @result.http_code
            end
          end
        end
      end

      private

      def bulk_search_params
        params.require(:data).map do |json|
          json.permit(:type, attributes: %i[input_description number_of_digits])
        end
      end

      def serialized_json_result
        Api::V2::BulkSearch::ResultCollectionSerializer.new(
          @result,
          include: ['searches.search_results'],
        ).serializable_hash
      end

      def serialized_csv_result
        Api::V2::Csv::BulkSearchResultSerializer.new(presented_searches).serialized_csv
      end

      def presented_searches
        if @result.completed?
          Api::V2::BulkSearchResultPresenter.wrap(@result)
        else
          []
        end
      end
    end
  end
end
